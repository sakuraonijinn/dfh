# Lab flake

One repo, four machines. Common behavior lives in `modules/`; each machine
only states what makes it different.

```
flake.nix
modules/
  common.nix           # every host: nix settings, gc, locale, base hardening
  sdcard-store.nix      # bind-mounts /nix/store onto an external sdcard
  hyprland-desktop.nix   # GUI stack — only imported by hub
  libvirt-host.nix        # libvirtd/virt-manager + USB redirection — only hub
  redbox-tools.nix        # FRP bypass + red team pentest toolchain — hub + redbox
hosts/
  hub/          # phone-lab: Hyprland GUI, internal 30G disk, own sdcard-store
  redbox/       # redbox: FRP bypass + pentest, own sdcard (VM on hub)
  ios/            # iosbox: iOS device analysis, own sdcard (VM on hub)
  forensics/       # forensicsbox: disk/file forensics, own sdcard (VM on hub)
```

Each `hosts/<name>/` has `configuration.nix` (what's unique to that
machine) and `hardware-configuration.nix` (machine-specific, currently a
placeholder for VM guests — see below).

## Architecture: hub is the only bare-metal box

`redbox`, `ios`, and `forensics` run as **libvirt/QEMU VMs on hub**
(`modules/libvirt-host.nix`) rather than separate physical machines —
each guest gets its own dedicated sdcard passed straight through as a block
device, so `modules/sdcard-store.nix` works exactly the same
inside a VM as it would on bare metal. See `docs/vm-setup.md` for the
libvirt side: creating each guest, and passing through both the sdcard
and whatever USB device that host needs to talk to (MTK dongle,
phone, card reader, write-blocker).

## Setup steps

1. Format each dedicated sdcard: `mkfs.ext4 -L nixstore /dev/sdX1`
2. Get its UUID: `lsblk -f` or `blkid /dev/sdX1`
3. Drop that UUID into `hosts/<name>/configuration.nix` →
   `sdcardStore.uuid = "...";`
4. Create the guest and pass the card through (`docs/vm-setup.md`), install
   NixOS inside it, then from **inside the guest**:
   `sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix`
   and copy that back into `hosts/<name>/hardware-configuration.nix` —
   VM disk layout (virtio) differs from bare metal, so don't reuse a
   physical machine's hardware config for a guest.
5. Access: guests use SSH-key access by default — add your pubkey to
   `hosts/<name>/configuration.nix` → `openssh.authorizedKeys.keys`.
   (If you do want a password fallback, generate the hash with the pipe
   pattern from AGENTS.md, never a redirect: `nix run nixpkgs#openssl --
   passwd -6 | tail -1 > secrets/<name>.hash`, chmod 600.)
6. Build: `sudo nixos-rebuild switch --flake .#<flake-attribute-name>`
   — this must match the flake attribute in `flake.nix`
   (`redbox`/`iosbox`/`forensicsbox`), which itself must match that host's
   `networking.hostName`. The `rebuild`/`update` aliases build against
   `$(hostname)`, so if these two ever drift apart, that alias silently
   points at a flake attribute that doesn't exist.

## Bringing up hub

Bare metal, on the internal 30G disk. Supply the real
`hardware-configuration.nix` (from `nixos-generate-config` on the
physical machine) and a password hash for `sakura`.

## Adding a fifth host later

Copy an existing `hosts/<name>/` directory, rename it, add its block to
`flake.nix`'s `nixosConfigurations`, decide whether it needs `sdcard-store`
or not, and give it a UUID/hardware config of its own.
Nothing in `modules/` needs to change.

## Day to day

`rebuild`, `update`, `gc`, and `logs` aliases are defined once in
`modules/common.nix` and available on every host — `rebuild` already
targets the right flake output via `$(hostname)`.
