# DNS appliance inventory capture

This USB is intentionally non-destructive until a production DNS image has
been built from inventory captured on each target HP computer.

## Capture one machine

1. Boot the `Debian Live 13.7.0` device-inspection entry from the Ventoy menu.
   Do not start an installer.
2. Open a root terminal and identify the wired interface and internal disk:

   ```sh
   ip -brief link
   lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN,RM
   ```

3. Locate and mount the `DEVICE-INST` partition:

   ```sh
   lsblk -o NAME,LABEL,FSTYPE,MOUNTPOINTS
   sudo mkdir -p /mnt/device-inst
   sudo mount -L DEVICE-INST /mnt/device-inst
   ```

4. Run the bundled capture command, substituting the role, address, interface,
   disk, and actual mounted path:

   ```sh
   sudo sh /mnt/device-inst/tools/capture-inventory \
     dns01 10.0.5.1 enp1s0 /dev/sda | \
     sudo tee /mnt/device-inst/inventory-dns01.conf >/dev/null
   sync
   ```

5. Re-open the generated file and confirm that the role and address are right.
   The identity values are SHA-256 hashes; `destructive_install_enabled` must
   remain `false` during capture.
6. Shut down and repeat for `dns02` and `dns03`. Never reuse one machine's file
   for another machine, even when their HP model numbers match.

The management host imports these three files into the ignored
`installer/inventory/local/` directory. It enables only the current pilot,
builds the guarded production image on amd64 Debian 13, and rewrites the USB.
The production image must not exist on the inventory-stage USB.
