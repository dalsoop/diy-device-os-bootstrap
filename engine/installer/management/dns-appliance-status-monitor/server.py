#!/usr/bin/env python3
"""Dependency-free, read-only status page for the three DNS appliances."""

from __future__ import annotations

import argparse
import concurrent.futures
import html
import ipaddress
import json
import secrets
import socket
import struct
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


PORTS = (("Cockpit", 9090), ("Technitium", 53443), ("Metrics", 9100))


def dns_name(name: str) -> bytes:
    labels = name.rstrip(".").split(".")
    encoded = bytearray()
    for label in labels:
        wire = label.encode("idna")
        if not wire or len(wire) > 63:
            raise ValueError(f"invalid DNS label: {label!r}")
        encoded.append(len(wire))
        encoded.extend(wire)
    encoded.append(0)
    return bytes(encoded)


def dns_packet(query: str, identifier: int) -> bytes:
    return struct.pack("!HHHHHH", identifier, 0x0100, 1, 0, 0, 0) + dns_name(query) + struct.pack("!HH", 1, 1)


def valid_dns_response(payload: bytes, identifier: int) -> bool:
    if len(payload) < 12:
        return False
    response_id, flags, _, answers, _, _ = struct.unpack("!HHHHHH", payload[:12])
    return response_id == identifier and flags & 0x8000 != 0 and flags & 0x000F == 0 and answers > 0


def check_dns(address: str, query: str, transport: str, timeout: float = 1.5) -> tuple[bool, str]:
    identifier = secrets.randbelow(65536)
    packet = dns_packet(query, identifier)
    started = time.monotonic()
    try:
        if transport == "udp":
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                client.settimeout(timeout)
                client.sendto(packet, (address, 53))
                response, _ = client.recvfrom(4096)
        else:
            with socket.create_connection((address, 53), timeout=timeout) as client:
                client.sendall(struct.pack("!H", len(packet)) + packet)
                size_data = client.recv(2)
                if len(size_data) != 2:
                    raise OSError("short TCP DNS length")
                expected = struct.unpack("!H", size_data)[0]
                chunks = bytearray()
                while len(chunks) < expected:
                    chunk = client.recv(expected - len(chunks))
                    if not chunk:
                        raise OSError("short TCP DNS response")
                    chunks.extend(chunk)
                response = bytes(chunks)
        elapsed = round((time.monotonic() - started) * 1000)
        return valid_dns_response(response, identifier), f"{elapsed} ms"
    except (OSError, ValueError) as error:
        return False, str(error)


def check_tcp(address: str, port: int, timeout: float = 1.5) -> tuple[bool, str]:
    started = time.monotonic()
    try:
        with socket.create_connection((address, port), timeout=timeout):
            elapsed = round((time.monotonic() - started) * 1000)
            return True, f"{elapsed} ms"
    except OSError as error:
        return False, str(error)


def check_node(node: dict[str, str]) -> dict[str, object]:
    address = str(ipaddress.ip_address(node["address"]))
    checks = []
    for transport in ("udp", "tcp"):
        ok, detail = check_dns(address, node["query"], transport)
        checks.append({"service": f"DNS {transport.upper()}", "ok": ok, "detail": detail})
    for service, port in PORTS:
        ok, detail = check_tcp(address, port)
        checks.append({"service": service, "ok": ok, "detail": detail})
    return {"name": node["name"], "address": address, "checks": checks}


def run_checks(config: dict[str, object]) -> list[dict[str, object]]:
    nodes = config["nodes"]
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(nodes)) as pool:
        return list(pool.map(check_node, nodes))


def render(config: dict[str, object], results: list[dict[str, object]]) -> bytes:
    rows = []
    for node in results:
        for check in node["checks"]:
            state = "정상" if check["ok"] else "실패"
            css = "ok" if check["ok"] else "bad"
            rows.append(
                "<tr>"
                f"<td>{html.escape(node['name'])}</td>"
                f"<td>{html.escape(node['address'])}</td>"
                f"<td>{html.escape(check['service'])}</td>"
                f"<td class='{css}'>{state}</td>"
                f"<td>{html.escape(check['detail'])}</td>"
                "</tr>"
            )
    refresh = int(config.get("refresh_seconds", 10))
    page = f"""<!doctype html>
<html lang="ko"><head><meta charset="utf-8"><meta http-equiv="refresh" content="{refresh}">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>DNS 장비 상태판</title>
<style>body{{font-family:system-ui,sans-serif;max-width:1100px;margin:2rem auto;padding:0 1rem;background:#111827;color:#f9fafb}}table{{width:100%;border-collapse:collapse;background:#1f2937}}th,td{{padding:.7rem;border-bottom:1px solid #374151;text-align:left}}.ok{{color:#34d399;font-weight:700}}.bad{{color:#fb7185;font-weight:700}}small{{color:#9ca3af}}</style>
</head><body><h1>DNS 장비 상태판</h1>
<p>설치 후 핵심 서비스가 응답하는지 읽기 전용으로 확인합니다.</p>
<table><thead><tr><th>장비</th><th>주소</th><th>서비스</th><th>상태</th><th>응답</th></tr></thead>
<tbody>{''.join(rows)}</tbody></table>
<p><small>{refresh}초마다 자동 갱신 · {time.strftime('%Y-%m-%d %H:%M:%S')}</small></p></body></html>"""
    return page.encode("utf-8")


def load_config(path: Path) -> dict[str, object]:
    config = json.loads(path.read_text(encoding="utf-8"))
    nodes = config.get("nodes")
    if not isinstance(nodes, list) or not nodes:
        raise ValueError("config must contain at least one node")
    for node in nodes:
        if not all(key in node for key in ("name", "address", "query")):
            raise ValueError("each node requires name, address, and query")
        ipaddress.ip_address(node["address"])
        dns_name(node["query"])
    return config


def main() -> None:
    parser = argparse.ArgumentParser(description="세 DNS 장비의 설치 후 상태를 확인합니다.")
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--listen", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--check-once", action="store_true")
    args = parser.parse_args()
    config = load_config(args.config)
    if args.check_once:
        print(json.dumps(run_checks(config), ensure_ascii=False, indent=2))
        return

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path not in ("/", "/index.html"):
                self.send_error(404)
                return
            body = render(config, run_checks(config))
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            return

    server = ThreadingHTTPServer((args.listen, args.port), Handler)
    print(f"DNS 장비 상태판: http://{args.listen}:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
