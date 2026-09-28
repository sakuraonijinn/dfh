# Bind-mounts /nix/store onto an external sdcard so the Nix store never
# touches internal storage. Import this on any "text-based, own dedicated
# card" host and set sdcardStore.uuid to that card's filesystem UUID
# (find it with `lsblk -f` or `blkid` after formatting: mkfs.ext4 -L nixstore /dev/sdX1).
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.sdcardStore;
in
{
  options.sdcardStore = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Bind-mount /nix/store onto an external sdcard.";
    };
    uuid = mkOption {
      type = types.str;
      description = "Filesystem UUID of the sdcard partition (blkid / lsblk -f).";
    };
    deviceTimeoutSeconds = mkOption {
      type = types.int;
      default = 60;
      description = "How long to wait for the card to enumerate before failing boot.";
    };
  };

  config = mkIf cfg.enable {
    boot.initrd.systemd.enable = true;

    boot.initrd.systemd.services.setupNixStore = {
      description = "Create Nix store directory on sdcard";
      after = [ "mnt-sdcard.mount" ];
      before = [ "nix-store.mount" ];
      wantedBy = [ "nix-store.mount" ];
      serviceConfig.Type = "oneshot";
      script = ''
        mkdir -p /mnt/sdcard/nix/store
      '';
    };

    fileSystems."/mnt/sdcard" = {
      device = "/dev/disk/by-uuid/${cfg.uuid}";
      fsType = "ext4";
      neededForBoot = true;
      options = [
        "noatime"
        "discard"
        "x-systemd.device-timeout=${toString cfg.deviceTimeoutSeconds}"
        "x-systemd.mount-timeout=${toString cfg.deviceTimeoutSeconds}"
      ];
    };

    fileSystems."/nix/store" = {
      device = "/mnt/sdcard/nix/store";
      fsType = "none";
      options = [
        "bind"
        "noatime"
        "x-systemd.requires-mounts-for=/mnt/sdcard"
      ];
      neededForBoot = true;
    };
  };
}
