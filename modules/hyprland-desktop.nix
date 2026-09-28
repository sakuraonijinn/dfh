# The GUI stack. Only imported by the hub — text-based hosts never pull
# this in, which is most of what keeps their sdcard closures small.
{ config, pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # NOTE: hyprpaper isn't a NixOS system module — configure it per-user via
  # ~/.config/hypr/hyprpaper.conf + `exec-once = hyprpaper` in hyprland.conf,
  # or via home-manager's `services.hyprpaper` if you adopt home-manager.

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  environment.systemPackages = with pkgs; [
    kitty waybar wofi mako wl-clipboard hyprpaper hyprlock hypridle
    dunst libnotify firefox nautilus gvfs glib networkmanagerapplet
    pavucontrol brightnessctl playerctl socat
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";              # Electron apps under Wayland
    MOZ_ENABLE_WAYLAND = "1";          # Firefox under Wayland
    _JAVA_AWM_NONREPARENTING = "1";    # Java GUI under Wayland
  };
}
