# DNS Appliance Status Monitor

This read-only Korean status page shows whether all three DNS appliances answer
after installation. It needs no external packages, account, or cloud service and
does not change the target nodes.

Run it on Pop!_OS or another Linux system with Python 3:

```sh
./start
```

Open <http://127.0.0.1:8080>. Every ten seconds it checks DNS over UDP and TCP,
Cockpit on 9090, Technitium management on 53443, and node exporter on 9100.
The server binds to localhost by default and is not exposed to other devices.

Edit `config.json` if node addresses or the canary name change. To expose the
page on the LAN, bind explicitly to a management-host address, for example
`./start --listen 10.0.0.X`, only after adding suitable firewall and access
controls.

