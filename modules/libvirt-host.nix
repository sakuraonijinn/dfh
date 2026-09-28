# Only imported by hub. Turns it into a VM host for frp/ios/forensics.
{ config, pkgs, lib, ... }:

{
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Lets virt-manager/virt-viewer redirect a USB device (phone, MTK dongle,
  # card reader) into a running guest without editing domain XML each time.
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    virt-manager
    qemu
    OVMF
    spice-gtk
  ];

  # Merges additively with the extraGroups list already set in
  # hosts/hub/configuration.nix — NixOS list options combine across files.
  users.users.sakura.extraGroups = [ "libvirtd" ];
}
