# forensics: disk/file forensics box. Text-based, own dedicated sdcard.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "forensicsbox";

  sdcardStore.uuid = "REPLACE-WITH-THIS-CARDS-UUID";

  users.users.forensics = {
    isNormalUser = true;
    extraGroups = [ "wheel" "plugdev" "dialout" ];
    hashedPasswordFile = "/etc/nixos/secrets/forensics.hash";
    openssh.authorizedKeys.keys = [
      # "ssh-ed25519 AAAA... your-key-comment"
    ];
  };
  users.groups.plugdev = {};

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # NOTE: package names below are a starting point — confirm exact spelling
  # with `nix search nixpkgs <name>` before your first rebuild.
  environment.systemPackages = with pkgs; [
    sleuthkit    # fls, icat, mmls, etc. — filesystem/disk-image analysis
    testdisk      # partition recovery + photorec file carving
    foremost       # file carving by header/footer
    binwalk         # firmware/blob analysis
    exiftool          # metadata extraction
    ddrescue           # imaging damaged media
    gnupg               # verify signed evidence/hashes
    hexedit               # raw hex viewing/editing
    yara                    # pattern matching against files
    p7zip
    file
  ];
}
