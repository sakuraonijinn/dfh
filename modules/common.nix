# Shared across every host. Host-specific files should NOT repeat any of
# this — just import it and layer on top.
{ config, pkgs, lib, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    min-free = 2 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
  nix.gc = {
    automatic = true;
    dates = "*-*-* 04:00:00";
    options = "--delete-older-than 2d";
  };
  nixpkgs.config = {
    allowUnfree = true;
    problems.handlers = {
      dataset.broken = "warn";
    };
  };

  networking.networkmanager.enable = lib.mkDefault true;
  networking.firewall.enable = true;

  services.openssh = {
    enable = lib.mkDefault false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.mutableUsers = false;

  environment.systemPackages = with pkgs; [
    git curl wget tree htop ripgrep openssh fd jq unzip gimp python3
  ];

  environment.interactiveShellInit = ''
    alias rebuild="sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)"
    alias update="sudo nix flake update --flake /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#$(hostname)"
    alias gc="sudo nix-collect-garbage -d && nix-collect-garbage -d"
    alias logs="journalctl -p 3 -xb"
  '';

  system.stateVersion = "25.05";
}
