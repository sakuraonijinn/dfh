# PLACEHOLDER — this host runs as a libvirt/QEMU guest on hub, not on
# bare metal. Install NixOS inside the VM first (see docs/vm-setup.md),
# then from INSIDE the guest run:
#   sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
# and copy the result back here — virtio disk/controller layout is
# different from bare-metal detection, so don't reuse a physical-machine
# hardware-configuration.nix for a VM guest.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  # fileSystems."/" = { device = "/dev/disk/by-uuid/REPLACE-ME"; fsType = "ext4"; };
  # boot.loader.grub.device = "/dev/vda"; # or switch to systemd-boot if UEFI
  # swapDevices = [ ];
}
