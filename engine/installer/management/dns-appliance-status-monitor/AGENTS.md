# DNS Appliance Status Monitor

This nested module serves a local, read-only HTML status page and probes the
three fixed DNS appliances.

- Keep the default listener on `127.0.0.1`. A non-loopback bind requires an
  explicit address plus separately managed firewall and access controls.
- Probes may read DNS over UDP/TCP and test TCP reachability for Cockpit,
  Technitium, and metrics. They must not authenticate, mutate nodes, or expose a
  write endpoint.
- Keep the runtime dependency-free beyond Python 3 so the copied USB bundle can
  run without installation or Internet access.
- Treat probe failure as status information, not permission to repair or change
  a node.
- Verify configuration parsing, loopback binding, expected probe labels, and
  failure rendering when changing the HTTP surface.

