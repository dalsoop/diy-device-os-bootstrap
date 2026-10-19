# DNS appliance inventory capture

This USB is intentionally non-destructive until a production DNS image has
been built from inventory captured on each target HP computer.

## Capture one machine

1. Boot the `Debian Live 13.7.0` device-inspection entry from the Ventoy menu.
   Do not start an installer.
2. At the shell prompt, mount the USB data partition and start the guided
   capture:

   ```sh
   sudo mount -L DEVICE-INST /mnt && sudo sh /mnt/tools/dns-inventory
   ```

3. Answer the three numbered questions: role (`dns01`, `dns02`, or `dns03`;
   the address follows from the role), wired interface, and internal disk.
   The lists already exclude loopback, virtual, and wireless interfaces, and
   the USB, removable, and loop disks. Type the role name to save.
4. The wizard writes only `/mnt/inventory-<role>.conf`, reads it back, and
   lists the roles captured so far. Identity values are SHA-256 hashes and
   `destructive_install_enabled` is always `false`. An existing file is kept
   unless you type `overwrite`.
5. Run `sudo umount /mnt`, shut down, and repeat on the next machine. Never
   reuse one machine's file for another machine, even when their HP model
   numbers match.

The wizard shows Korean in a terminal that can draw Hangul. The Linux text
console cannot, so the wizard uses English there; `--lang ko` or `--lang en`
overrides the choice.

## Manual fallback

If the wizard cannot run, identify the interface and disk with
`ip -brief link` and `lsblk -d -o NAME,MODEL,SERIAL,SIZE,TRAN,RM`, then run the
capture command directly:

```sh
sudo sh /mnt/tools/capture-inventory dns01 10.0.5.1 enp1s0 /dev/sda | \
  sudo tee /mnt/inventory-dns01.conf >/dev/null
sync
```

The management host imports these three files into the ignored
`installer/inventory/local/` directory. It enables only the current pilot,
builds the guarded production image on amd64 Debian 13, and rewrites the USB.
The production image must not exist on the inventory-stage USB.
