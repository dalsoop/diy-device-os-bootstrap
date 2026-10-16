#!/usr/bin/env python3
"""Isolated contract simulation for the management-host MCP gateway."""

from __future__ import annotations

import asyncio
import importlib.util
import json
import os
from pathlib import Path
import stat
import tempfile

from mcp import Client
from mcp.server.mcpserver.exceptions import ToolError


AGENT_ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location(
    "device_os_agent_server", AGENT_ROOT / "server.py"
)
assert SPEC and SPEC.loader
server = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(server)


def executable(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body, encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)


def expect_tool_error(action, text: str) -> None:
    try:
        action()
    except ToolError as error:
        assert text in str(error), str(error)
    else:
        raise AssertionError(f"expected ToolError containing: {text}")


async def inspect_tools() -> None:
    async with Client(server.mcp) as client:
        listed = await client.list_tools()
        names = {tool.name for tool in listed.tools}
        assert names == {
            "repository_status",
            "world_validate",
            "world_plan",
            "world_simulate",
            "world_capacity",
            "network_preflight",
            "tunnel_status",
            "dns_health",
            "dns_plan",
            "dns_apply",
        }
        assert not names.intersection(
            {"burn", "write", "restore", "reinstall", "shell", "exec"}
        )
        validated = await client.call_tool("world_validate", {})
        assert validated.is_error is not True
        assert validated.structured_content["ok"] is True


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="device-os-agent-test-") as temporary:
        root = Path(temporary)
        invocation = root / "invocation.json"
        token = root / "applier.token"
        ca_file = root / "technitium-ca.pem"
        token.write_text("test-token\n", encoding="utf-8")
        token.chmod(0o600)
        ca_file.write_text("test-ca\n", encoding="utf-8")
        (root / "installer" / "zones").mkdir(parents=True)
        (root / "installer" / "zones" / "home.arpa.zone").write_text(
            "$ORIGIN home.arpa.\n", encoding="utf-8"
        )
        executable(
            root / "device-os",
            "#!/bin/sh\n"
            "set -eu\n"
            "printf '{\"command\":\"%s %s\",\"offline\":\"%s\"}\\n' "
            '"${2:-}" "${3:-}" "${6:-}"\n',
        )
        executable(
            root / "installer" / "management" / "network-preflight",
            "#!/bin/sh\n"
            "set -eu\n"
            "[ \"$1\" = --json ]\n"
            "if [ \"${2:-}\" = --offline ]; then\n"
            "  printf '{\"router_cidr\":\"%s\",\"internet_checked\":false}\\n' \"$3\"\n"
            "else\n"
            "  printf '{\"router_cidr\":\"%s\",\"internet_checked\":true}\\n' \"$2\"\n"
            "fi\n",
        )
        executable(
            root / "installer" / "management" / "dnsctl",
            "#!/bin/sh\n"
            "set -eu\n"
            "python3 - \"$@\" <<'PY'\n"
            "import json, os, sys\n"
            f"json.dump({{'argv': sys.argv[1:], 'env': {{k: v for k, v in os.environ.items() if k.startswith('TECHNITIUM_')}}, 'has_openai_key': 'OPENAI_API_KEY' in os.environ}}, open({str(invocation)!r}, 'w'))\n"
            "print('{\"status\":\"ok\"}')\n"
            "PY\n",
        )
        executable(
            root / "bin" / "tailscale",
            "#!/bin/sh\n"
            "set -eu\n"
            "[ -n \"${SHLVL:-}\" ]\n"
            "printf '%s\\n' '{\"BackendState\":\"Running\",\"Self\":{\"HostName\":\"management\"},\"Peer\":{\"a\":{\"HostName\":\"dns01\",\"Online\":true,\"TailscaleIPs\":[\"100.64.0.1\"]},\"b\":{\"HostName\":\"unrelated\",\"Online\":true,\"TailscaleIPs\":[\"100.64.0.9\"]}}}'\n",
        )

        server.gateway = server.Gateway(root)
        result = server.gateway.world_validate()
        assert result["ok"] is True
        capacity = server.gateway.world_capacity("16GB")
        assert capacity["data"]["offline"] == "--offline"
        expect_tool_error(
            lambda: server.gateway.world_capacity("/dev/disk0"),
            "capacity must look like",
        )
        expect_tool_error(
            lambda: server.gateway.network_preflight("not-a-network"),
            "router_cidr is invalid",
        )
        network = server.gateway.network_preflight("10.0.0.1/16")
        assert network["data"]["internet_checked"] is True
        offline_network = server.gateway.network_preflight(
            "10.0.0.1/16", check_internet=False
        )
        assert offline_network["data"]["internet_checked"] is False
        os.environ["DEVICE_OS_AGENT_TAILSCALE_COMMAND"] = "relative/tailscale"
        expect_tool_error(
            server.gateway.tunnel_status,
            "configured Tailscale command is unavailable",
        )
        os.environ["DEVICE_OS_AGENT_TAILSCALE_COMMAND"] = str(
            root / "bin" / "tailscale"
        )
        tunnel = server.gateway.tunnel_status()
        assert set(tunnel["data"]["dns_nodes"]) == {"dns01"}

        commit = "a" * 40
        os.environ["DEVICE_OS_AGENT_DNS_APPLIER_TOKEN_FILE"] = str(token)
        os.environ["DEVICE_OS_AGENT_DNS01_URL"] = "https://dns01:53443"
        os.environ["DEVICE_OS_AGENT_TECHNITIUM_CA_FILE"] = str(ca_file)
        os.environ["OPENAI_API_KEY"] = "must-not-reach-child"
        os.environ.pop("DEVICE_OS_AGENT_ALLOW_APPLY", None)
        expect_tool_error(
            lambda: server.gateway.dns_apply(
                "dns01", commit, f"APPLY home.arpa TO dns01 AT {commit}"
            ),
            "disabled",
        )
        os.environ["DEVICE_OS_AGENT_ALLOW_APPLY"] = "1"
        expect_tool_error(
            lambda: server.gateway.dns_apply("dns01", commit, "APPLY"),
            "confirmation must exactly equal",
        )
        token.chmod(0o644)
        expect_tool_error(
            lambda: server.gateway.dns_apply(
                "dns01", commit, f"APPLY home.arpa TO dns01 AT {commit}"
            ),
            "must not be accessible by group or others",
        )
        token.chmod(0o600)
        applied = server.gateway.dns_apply(
            "dns01", commit, f"APPLY home.arpa TO dns01 AT {commit}"
        )
        assert applied["ok"] is True
        recorded = json.loads(invocation.read_text(encoding="utf-8"))
        assert recorded["argv"][-4:] == [
            "--approved-commit",
            commit,
            "--confirm",
            "APPLY",
        ]
        assert recorded["env"] == {
            "TECHNITIUM_CA_FILE": str(ca_file),
            "TECHNITIUM_TOKEN_FILE": str(token),
            "TECHNITIUM_URL": "https://dns01:53443",
        }
        assert recorded["has_openai_key"] is False
        assert "test-token" not in invocation.read_text(encoding="utf-8")

        asyncio.run(inspect_tools())
        print("agent gateway simulations: passed")


if __name__ == "__main__":
    main()
