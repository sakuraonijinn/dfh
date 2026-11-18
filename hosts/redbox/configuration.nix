# redbox: libvirt guest on phone-lab. Headless red-team / Android-test VM.
#
# Self-contained on purpose: it does NOT import modules/common.nix, because
# common.nix points user passwords at /etc/nixos/secrets/*.hash, and those
# files do not exist inside a freshly built qcow2 image (the flake cannot
# read the host's secrets dir at build time). Give sakura an initialPassword,
# log in once, then either change it or move to a secrets file mounted at boot.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "redbox";

  time.timeZone = "UTC";

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Matches make-disk-image.nix partitionTableType = "legacy":
  # whole disk is one ext4 partition, MBR boot. Legacy partition layouts on
  # purpose — libvirt's default SeaBIOS boots it with zero extra firmware.
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  users.users.root = {
    isNormalUser = false;
    hashedPassword = "!";   # locked: no console/ssh login as root
  };

  users.users.sakura = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "networkmanager" "adbusers" "video" "input" ];
    initialPassword = "change-me-once";   # remove after first boot + passwd
    openssh.authorizedKeys.keys = [
      # paste your lab key here BEFORE first boot; it is how you get in
      # "ssh-ed25519 AAAA... sakura@phone-lab"
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.qemuGuest.enable = true;

  # No desktop: this box is driven by ssh + its own console.
  environment.systemPackages = with pkgs; [
    htop     python3
    # ── Android test surface (Scenario X post-entry deck) ──
    android-tools
    frida-tools
    mitmproxy
    tcpdump
    (python3.withPackages (p: with p; [
      frida-python scapy requests
    ]))
  ];

  programs.adb.enable = true;

  # Termux/gadget devices arrive over libvirt's default NAT network.
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.05";
}
