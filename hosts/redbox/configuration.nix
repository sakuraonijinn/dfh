# Redbox — FRP bypass + red team pentesting host.
# Replaces the old frpbox (MediaTek-only). Text-based, own dedicated sdcard.
# Runs as a libvirt/QEMU VM on hub.
# Tools: mtkclient, FRP bypass, apktool/jadx/frida, mitmproxy, pentest suite.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "redbox";

  # Headless access: serial console for `virsh console redbox` when the guest
  # has no GUI and network is still being brought up.
  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  systemd.services."serial-getty@ttyS0" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  sdcardStore.uuid = "REPLACE-WITH-THIS-CARDS-UUID";

  # Allow root login in initrd emergency mode for debugging.
  boot.initrd.systemd.emergencyAccess = true;

  users.users.root.hashedPasswordFile = "/etc/nixos/secrets/redbox.hash";

  users.users.redbox = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID216FYTVrWktumNsE+hHdNlMtupQxeQ8GH6y4en8YB0 sakura@phone-lab"
    ];
  };
  users.groups.plugdev = {};

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # FRP bypass and device access udev rules
  services.udev.extraRules = ''
    # MediaTek devices (MTK flashing/FRP)
    SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    # USB mass storage (sdcard readers, USB drives)
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    # Apple devices (iOS FRP/backup)
    SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    # Generic ADB devices
    SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';
}
