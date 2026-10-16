#!/usr/bin/env python3
"""Constrained MCP gateway for DIY Device OS Bootstrap."""

from __future__ import annotations

import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from typing import Literal
from urllib.parse import urlsplit

from mcp.server import MCPServer
from mcp.server.mcpserver.exceptions import ToolError
from mcp.types import ToolAnnotations


Role = Literal["dns01", "dns02", "dns03"]
ROLES: tuple[Role, ...] = ("dns01", "dns02", "dns03")
CAPACITY_PATTERN = re.compile(r"^[1-9][0-9]*(?:\.[0-9]+)?(?:GB|GiB|TB|TiB)$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
MAX_OUTPUT_BYTES = 64 * 1024


def _clip(value: str) -> str:
    encoded = value.encode("utf-8", errors="replace")
    if len(encoded) <= MAX_OUTPUT_BYTES:
        return value
    clipped = encoded[:MAX_OUTPUT_BYTES].decode("utf-8", errors="replace")
    return f"{clipped}\n[output truncated by device-os-agent]"


def _data(value: str) -> object:
    stripped = value.strip()
    if not stripped:
        return None
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        return stripped


class Gateway:
    """Runs a fixed command allowlist with a fixed environment allowlist."""

    def __init__(self, repo_root: Path | None = None) -> None:
        self.repo_root = (
            repo_root or Path(__file__).resolve().parent.parent
        ).resolve()
        self.device_os = self.repo_root / "device-os"
        self.management = self.repo_root / "installer" / "management"
        self.zone_file = self.repo_root / "installer" / "zones" / "home.arpa.zone"
        self.state_dir = Path(
            os.environ.get(
                "DEVICE_OS_AGENT_STATE_DIR",
                str(Path.home() / ".local" / "state" / "device-os-agent"),
            )
        ).expanduser()

    def _environment(self, extra: dict[str, str] | None = None) -> dict[str, str]:
        environment = {
            "PATH": os.environ.get("PATH", "/usr/local/bin:/usr/bin:/bin"),
            "LANG": os.environ.get("LANG", "C.UTF-8"),
            "LC_ALL": os.environ.get("LC_ALL", "C.UTF-8"),
            "XDG_STATE_HOME": str(self.state_dir),
            "DNSCTL_AUDIT_LOG": str(self.state_dir / "dnsctl-audit.jsonl"),
        }
        for name in ("TMPDIR", "SSL_CERT_FILE", "SSL_CERT_DIR"):
            value = os.environ.get(name)
            if value:
                environment[name] = value
        for name in ("DEVICE_OS_WORLD", "DEVICE_OS_MEDIA"):
            value = os.environ.get(name)
            if value:
                environment[name] = value
        if extra:
            environment.update(extra)
        return environment

    def _run(
        self,
        operation: str,
        arguments: list[str],
        *,
        timeout: int = 60,
        extra_environment: dict[str, str] | None = None,
    ) -> dict[str, object]:
        try:
            completed = subprocess.run(
                arguments,
                cwd=self.repo_root,
                env=self._environment(extra_environment),
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except FileNotFoundError as error:
            raise ToolError(f"{operation}: required command is unavailable") from error
        except subprocess.TimeoutExpired as error:
            raise ToolError(f"{operation}: timed out after {timeout} seconds") from error

        stdout = _clip(completed.stdout)
        stderr = _clip(completed.stderr)
        if completed.returncode != 0:
            detail = stderr.strip() or stdout.strip() or "command failed without output"
            raise ToolError(f"{operation}: {detail}")
        return {
            "schema_version": 1,
            "operation": operation,
            "ok": True,
            "data": _data(stdout),
            "diagnostics": stderr.strip() or None,
        }

    def _world(self, operation: str) -> dict[str, object]:
        return self._run(
            f"world.{operation}",
            [str(self.device_os), "world", operation],
            timeout=120,
        )

    def repository_status(self) -> dict[str, object]:
        revision = self._run(
            "repository.revision", ["git", "rev-parse", "HEAD"]
        )["data"]
        branch = self._run(
            "repository.branch", ["git", "branch", "--show-current"]
        )["data"]
        status = self._run(
            "repository.status", ["git", "status", "--short"]
        )["data"]
        return {
            "schema_version": 1,
            "operation": "repository.status",
            "ok": True,
            "data": {
                "revision": revision,
                "branch": branch,
                "clean": status is None,
                "changes": [] if status is None else str(status).splitlines(),
            },
            "diagnostics": None,
        }

    def world_validate(self) -> dict[str, object]:
        return self._world("validate")

    def world_plan(self) -> dict[str, object]:
        return self._world("plan")

    def world_simulate(self) -> dict[str, object]:
        return self._world("simulate")

    def world_capacity(
        self, capacity: str, allow_network_probe: bool = False
    ) -> dict[str, object]:
        if not CAPACITY_PATTERN.fullmatch(capacity):
            raise ToolError("world.capacity: capacity must look like 16GB or 16GiB")
        arguments = [
            str(self.device_os),
            "world",
            "capacity",
            "--capacity",
            capacity,
            "--json",
        ]
        if not allow_network_probe:
            arguments.append("--offline")
        return self._run("world.capacity", arguments, timeout=120)

    def network_preflight(
        self, router_cidr: str, check_internet: bool = True
    ) -> dict[str, object]:
        try:
            interface = ipaddress.ip_interface(router_cidr)
        except ValueError as error:
            raise ToolError("network.preflight: router_cidr is invalid") from error
        if interface.version != 4:
            raise ToolError("network.preflight: only IPv4 is supported")
        arguments = [
            str(self.management / "network-preflight"),
            "--json",
            str(interface),
        ]
        if not check_internet:
            arguments.insert(2, "--offline")
        return self._run("network.preflight", arguments, timeout=30)

    def tunnel_status(self) -> dict[str, object]:
        configured_command = os.environ.get("DEVICE_OS_AGENT_TAILSCALE_COMMAND")
        tailscale_environment: dict[str, str] | None = None
        if configured_command:
            command_path = Path(configured_command)
            if not command_path.is_absolute() or not os.access(command_path, os.X_OK):
                raise ToolError(
                    "tunnel.status: configured Tailscale command is unavailable"
                )
            tailscale = str(command_path)
            tailscale_environment = {"SHLVL": os.environ.get("SHLVL", "1")}
        else:
            tailscale = shutil.which("tailscale", path=self._environment()["PATH"])
        if not tailscale:
            raise ToolError("tunnel.status: tailscale CLI is unavailable")
        result = self._run(
            "tunnel.status",
            [tailscale, "status", "--json"],
            timeout=20,
            extra_environment=tailscale_environment,
        )
        raw = result["data"]
        if not isinstance(raw, dict):
            raise ToolError("tunnel.status: Tailscale returned invalid JSON")
        peers = raw.get("Peer", {})
        visible: dict[str, object] = {}
        if isinstance(peers, dict):
            for peer in peers.values():
                if not isinstance(peer, dict):
                    continue
                hostname = peer.get("HostName")
                if hostname not in ROLES:
                    continue
                visible[str(hostname)] = {
                    "online": bool(peer.get("Online")),
                    "tailscale_ips": peer.get("TailscaleIPs", []),
                }
        return {
            "schema_version": 1,
            "operation": "tunnel.status",
            "ok": True,
            "data": {
                "backend_state": raw.get("BackendState"),
                "management_host": {
                    "hostname": (raw.get("Self") or {}).get("HostName")
                    if isinstance(raw.get("Self"), dict)
                    else None,
                },
                "dns_nodes": visible,
            },
            "diagnostics": None,
        }

    @staticmethod
    def _validate_role(role: str) -> Role:
        if role not in ROLES:
            raise ToolError("DNS role must be dns01, dns02, or dns03")
        return role  # type: ignore[return-value]

    @staticmethod
    def _validate_url(value: str, role: Role) -> str:
        parsed = urlsplit(value)
        if (
            parsed.scheme != "https"
            or not parsed.hostname
            or parsed.username
            or parsed.password
            or parsed.query
            or parsed.fragment
            or parsed.path not in ("", "/")
        ):
            raise ToolError(f"dns.{role}: endpoint must be an HTTPS origin")
        return value.rstrip("/")

    def _dns_environment(self, role: str, access: str) -> dict[str, str]:
        validated_role = self._validate_role(role)
        token_name = f"DEVICE_OS_AGENT_DNS_{access.upper()}_TOKEN_FILE"
        token_file = os.environ.get(token_name)
        if not token_file:
            raise ToolError(f"dns.{access}: management host has no {access} token file")
        token_path = Path(token_file)
        if not token_path.is_absolute() or not token_path.is_file():
            raise ToolError(f"dns.{access}: configured token file is unavailable")
        if token_path.stat().st_mode & 0o077:
            raise ToolError(
                f"dns.{access}: token file must not be accessible by group or others"
            )
        url_name = f"DEVICE_OS_AGENT_{validated_role.upper()}_URL"
        url = self._validate_url(
            os.environ.get(url_name, f"https://{validated_role}:53443"),
            validated_role,
        )
        environment = {
            "TECHNITIUM_URL": url,
            "TECHNITIUM_TOKEN_FILE": str(token_path),
        }
        ca_file = os.environ.get("DEVICE_OS_AGENT_TECHNITIUM_CA_FILE")
        if ca_file:
            ca_path = Path(ca_file)
            if not ca_path.is_absolute() or not ca_path.is_file():
                raise ToolError(f"dns.{access}: configured CA file is unavailable")
            environment["TECHNITIUM_CA_FILE"] = str(ca_path)
        elif access == "applier":
            raise ToolError("dns.apply: a trusted Technitium CA file is required")
        return environment

    def dns_health(self, role: str) -> dict[str, object]:
        environment = self._dns_environment(role, "reader")
        return self._run(
            f"dns.health.{role}",
            [str(self.management / "dnsctl"), "health"],
            timeout=30,
            extra_environment=environment,
        )

    def dns_plan(self, role: str) -> dict[str, object]:
        environment = self._dns_environment(role, "planner")
        return self._run(
            f"dns.plan.{role}",
            [str(self.management / "dnsctl"), "plan", str(self.zone_file)],
            timeout=60,
            extra_environment=environment,
        )

    def dns_apply(
        self, role: str, approved_commit: str, confirmation: str
    ) -> dict[str, object]:
        validated_role = self._validate_role(role)
        if os.environ.get("DEVICE_OS_AGENT_ALLOW_APPLY") != "1":
            raise ToolError("dns.apply: disabled on this management host")
        if not COMMIT_PATTERN.fullmatch(approved_commit):
            raise ToolError("dns.apply: approved_commit must be a full lowercase commit ID")
        expected = f"APPLY home.arpa TO {validated_role} AT {approved_commit}"
        if confirmation != expected:
            raise ToolError(f"dns.apply: confirmation must exactly equal {expected}")
        environment = self._dns_environment(validated_role, "applier")
        return self._run(
            f"dns.apply.{validated_role}",
            [
                str(self.management / "dnsctl"),
                "apply",
                str(self.zone_file),
                "--approved-commit",
                approved_commit,
                "--confirm",
                "APPLY",
            ],
            timeout=90,
            extra_environment=environment,
        )


gateway = Gateway()
mcp = MCPServer(
    "diy-device-os-bootstrap",
    title="DIY Device OS Bootstrap",
    version="0.1.0",
    instructions=(
        "Operate only through these constrained tools. Planning and simulation do not "
        "prove that a USB was written or a device was installed. Never claim a higher "
        "verification state than the returned evidence."
    ),
)

READ_ONLY_LOCAL = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=False,
)
READ_ONLY_NETWORK = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=True,
)


@mcp.tool(annotations=READ_ONLY_LOCAL, structured_output=True)
def repository_status() -> dict[str, object]:
    """Return the checked-out revision, branch, and dirty-file list."""
    return gateway.repository_status()


@mcp.tool(annotations=READ_ONLY_LOCAL, structured_output=True)
def world_validate() -> dict[str, object]:
    """Validate the selected World without downloads or device writes."""
    return gateway.world_validate()


@mcp.tool(annotations=READ_ONLY_LOCAL, structured_output=True)
def world_plan() -> dict[str, object]:
    """Resolve and display the selected World media plan."""
    return gateway.world_plan()


@mcp.tool(annotations=READ_ONLY_LOCAL, structured_output=True)
def world_simulate() -> dict[str, object]:
    """Simulate the World workflow without downloads or device writes."""
    return gateway.world_simulate()


@mcp.tool(annotations=READ_ONLY_NETWORK, structured_output=True)
def world_capacity(
    capacity: str = "16GB", allow_network_probe: bool = False
) -> dict[str, object]:
    """Calculate USB fit; network size probes are disabled by default."""
    return gateway.world_capacity(capacity, allow_network_probe)


@mcp.tool(annotations=READ_ONLY_NETWORK, structured_output=True)
def network_preflight(
    router_cidr: str = "10.0.0.1/16", check_internet: bool = True
) -> dict[str, object]:
    """Check topology, LAN reachability, and fixed Internet connectivity probes."""
    return gateway.network_preflight(router_cidr, check_internet)


@mcp.tool(annotations=READ_ONLY_NETWORK, structured_output=True)
def tunnel_status() -> dict[str, object]:
    """Return only the management host and dns01-dns03 Tailscale state."""
    return gateway.tunnel_status()


@mcp.tool(annotations=READ_ONLY_NETWORK, structured_output=True)
def dns_health(role: Role) -> dict[str, object]:
    """Read one DNS node's health through its reader credential."""
    return gateway.dns_health(role)


@mcp.tool(annotations=READ_ONLY_NETWORK, structured_output=True)
def dns_plan(role: Role) -> dict[str, object]:
    """Compare the tracked home.arpa zone with one node without applying it."""
    return gateway.dns_plan(role)


@mcp.tool(
    annotations=ToolAnnotations(
        readOnlyHint=False,
        destructiveHint=True,
        idempotentHint=True,
        openWorldHint=True,
    ),
    structured_output=True,
)
def dns_apply(
    role: Role, approved_commit: str, confirmation: str
) -> dict[str, object]:
    """Apply the tracked zone when host policy and all delegated gates allow it."""
    return gateway.dns_apply(role, approved_commit, confirmation)


def main() -> None:
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()
