# Router and network cutover

## Address prerequisite

The selected addresses assume one `10.0.0.0/16` LAN. The router interface must
therefore be `10.0.0.1/16` (`255.255.0.0`) or provide an explicit routed path to
`10.0.5.0/24`. A factory-default `/24` router configuration does not satisfy
this design.

Before changing the router, retain a wired management client and a documented
way to restore its previous LAN address and mask. Record the old DHCP DNS values.
Run the static check from the management machine:

```sh
management/network-preflight 10.0.0.1/16
```

## Cabling

Connect the router LAN port and all three HP machines to the same managed or
unmanaged gigabit switch. Do not connect a second router DHCP server. During
installation, leave the installer USB attached only to the machine being
installed.

## Ordered cutover

1. Confirm the router LAN mask is `/16`; do not change DHCP DNS yet.
2. Install and verify `dns01`, then `dns02`, then `dns03` one at a time.
3. Bootstrap the Technitium cluster and import `home.arpa`.
4. From two independent clients, query every node over UDP and TCP:

   ```sh
   for ip in 10.0.5.1 10.0.5.2 10.0.5.3; do
     dig +short "@$ip" canary.home.arpa A
     dig +tcp +short "@$ip" canary.home.arpa A
   done
   ```

5. Confirm NTP, Cockpit, node metrics, an encrypted backup, and cluster state.
6. Configure router DHCP DNS in this order: `10.0.5.1`, `10.0.5.2`,
   `10.0.5.3`. Technitium clustering synchronizes configuration; DHCP must still
   advertise multiple resolver addresses for client-side redundancy.
7. Renew one test client's DHCP lease and verify public and `home.arpa` names.
8. Renew the remaining clients only after the canary remains healthy.

## Rollback

If any canary fails, restore the previous router DHCP DNS values first. Existing
appliances can remain online while the cause is investigated. Do not alter all
three nodes together, and do not delete the old DHCP values until a full lease
cycle has passed successfully.

Router web interfaces and firmware differ, so this repository does not automate
the router mutation without a documented, authenticated, reversible API.
