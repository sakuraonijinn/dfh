# ios: iOS device analysis box. Text-based, own dedicated sdcard.
# VM not created yet — config is a working draft; sdcardStore.uuid must be
# filled in with the actual card's UUID before first install (see README).
{ config, pkgs, lib, ... }:

{
  networking.hostName = "iosbox";

  sdcardStore.uuid = "REPLACE-WITH-THIS-CARDS-UUID";

  users.users.ios = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" "dialout" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID216FYTVrWktumNsE+hHdNlMtupQxeQ8GH6y4en8YB0 sakura@phone-lab"
    ];
  };
  users.groups.plugdev = {};

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # usbmuxd for iOS device pairing; idevice tools for basic device access.
  environment.systemPackages = with pkgs; [
    usbmuxd
    libimobiledevice
    usbutils
    p7zip
    file
  ];
}
