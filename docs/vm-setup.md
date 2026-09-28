# Running redbox / ios / forensics as VMs on hub

The Nix side (`sdcardStore.uuid`, per-host packages) doesn't change —
a passed-through block device still shows up in the guest under
`/dev/disk/by-uuid/<uuid>` exactly like it would on bare metal, so
`modules/sdcard-store.nix` works unmodified. What's different is how
the card and any USB device (phone, MTK dongle, card reader) get into
the guest in the first place — that's a libvirt-level concern, not a
NixOS option.

## 1. Create the guest

Give each VM a small virtual disk for `/boot` + root (a few GB is enough —
`/nix/store` isn't going on it), and pass the physical sdcard straight
through as a second disk.

```
virt-install \
  --name redbox \
  --memory 4096 --vcpus 2 \
  --disk size=8,path=/var/lib/libvirt/images/redbox-root.qcow2 \
  --disk /dev/disk/by-id/usb-<your-sdcard-reader-id>,bus=virtio \
  --os-variant nixos-unstable \
  --network network=default \
  --graphics spice \
  --cdrom /path/to/nixos-minimal.iso
```

Find the card reader's stable id with `ls -l /dev/disk/by-id/ | grep usb`
rather than `/dev/sdX` — the letter can shift between boots.

Install NixOS on the small virtual disk as normal, get the guest's real
`hardware-configuration.nix` from inside it, drop it into
`hosts/<name>/hardware-configuration.nix`, then apply this flake's config
for that host as usual (`nixos-rebuild switch --flake .#redbox`, run from
inside the guest, or copy the repo in).

## 2. Live-attach/detach the actual USB device

For the MTK dongle, phone, or card reader that needs to come and go (as
opposed to the sdcard disk, which stays attached permanently), use
`virsh attach-device` / `detach-device` rather than baking it into the
domain XML — this lets you unplug from the host and hand it to a
different guest without editing configs.

Find the device:
```
lsusb
# Bus 003 Device 012: ID 0e8d:0003 MediaTek Inc.
```

`usb-redbox.xml`:
```xml
<hostdev mode='subsystem' type='usb'>
  <source>
    <vendor id='0x0e8d'/>
    <product id='0x0003'/>
  </source>
</hostdev>
```

Attach / detach:
```
virsh attach-device redbox usb-redbox.xml --live
virsh detach-device redbox usb-redbox.xml --live
```

Same pattern for the ios guest with the iPhone's vendor/product ID
(`0x05ac`), or a forensics write-blocker.

## 3. Permissions

The `redbox` config's existing udev rule (vendor `0e8d` → `plugdev` group)
still matters — it applies *inside the guest* once the device is attached,
same as it would on bare metal. `virt-manager`'s Spice USB redirection
(enabled by `modules/libvirt-host.nix`) is an easier day-to-day option
than `virsh attach-device` if you're doing this interactively rather than
scripting it.

## 4. Redbox-specific: FRP bypass workflow

Redbox combines MTK flashing + FRP removal + app pentesting in one VM.

### For FRP / screen lock removal
1. Plug the target device into hub's USB
2. `redbox-start` (starts the redbox VM)
3. `redbox-console` (or SSH to redbox)
4. Use `mtk` for MTK devices, or ADB for Samsung/other Android
5. Tools available: `mtkclient`, `adb`, `frp-bypass-apk`, `frp-drfone`

### For app pentesting
1. `redbox-start`
2. `redbox-console`
3. `proxy-on` (starts mitmproxy + sets proxy on connected device)
4. `frida-run <package> <script.js>` (dynamic instrumentation)
5. `apktool d target.apk` (decompile)
6. `jadx -d target.apk output/` (Java decompilation)
