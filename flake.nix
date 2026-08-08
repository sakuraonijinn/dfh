{
  description = "Lab machines: GUI hub + dedicated text-based sdcard-store hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {

        # ── GUI hub: Hyprland desktop, lives on the internal 30G disk ──
        # Attribute name MUST match networking.hostName in
        # hosts/hub/configuration.nix ("phone-lab") — the `rebuild`/`update`
        # aliases in modules/common.nix build --flake .#$(hostname), so the
        # two have to agree or that alias breaks.
        "phone-lab" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/hyprland-desktop.nix
            ./modules/libvirt-host.nix
            ./hosts/hub/configuration.nix
            ./hosts/hub/hardware-configuration.nix
          ];
        };

        # ── frp: MediaTek flashing/recovery box, sdcard-backed store ──
        # Attribute name matches networking.hostName ("frpbox") in
        # hosts/frp/configuration.nix — same reasoning as phone-lab above.
        frpbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/sdcard-store.nix
            ./hosts/frp/configuration.nix
            ./hosts/frp/hardware-configuration.nix
          ];
        };

        # ── ios: iOS device analysis, sdcard-backed store ──
        # Attribute name matches networking.hostName ("iosbox").
        iosbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/sdcard-store.nix
            ./hosts/ios/configuration.nix
            ./hosts/ios/hardware-configuration.nix
          ];
        };

        # ── forensics: disk/memory/file forensics, sdcard-backed store ──
        # Attribute name matches networking.hostName ("forensicsbox").
        forensicsbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/sdcard-store.nix
            ./hosts/forensics/configuration.nix
            ./hosts/forensics/hardware-configuration.nix
          ];
        };
      };
    };
}
