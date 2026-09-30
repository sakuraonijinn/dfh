{
  description = "Lab machines: GUI hub + dedicated text-based sdcard-store hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    opencode.url = "github:dan-online/opencode-nix";
    opencode.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, opencode, ... }:
    let
      system = "x86_64-linux";
    in
    {
      # Genymotion's official Linux package is a closed-source .bin installer
      # that nixpkgs dropped, so it is packaged locally in
      # ./modules/genymotion.nix and exposed as its own package output.
      # It is deliberately NOT a NixOS module: it is a plain package
      # expression ({ lib, which, stdenv, ... }: stdenv.mkDerivation), so
      # listing it in a nixosConfiguration's `modules` list makes the
      # module system recurse infinitely (it takes module args and hands
      # them back to itself).
      packages.${system}.default = nixpkgs.legacyPackages.${system}.callPackage
        ./modules/genymotion.nix { };

      nixosConfigurations = {

        "phone-lab" = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            { nixpkgs.overlays = [ opencode.overlays.default ]; }
            ./modules/common.nix
            ./modules/hyprland-desktop.nix
            ./modules/libvirt-host.nix
            ./modules/sdcard-store.nix
            ./modules/redbox-tools.nix
            ./hosts/hub/configuration.nix
            ./hosts/hub/hardware-configuration.nix
          ];
        };

        redbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/sdcard-store.nix
            ./modules/redbox-tools.nix
            ./hosts/redbox/configuration.nix
            ./hosts/redbox/hardware-configuration.nix
          ];
        };

        iosbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./modules/common.nix
            ./modules/sdcard-store.nix
            ./hosts/ios/configuration.nix
            ./hosts/ios/hardware-configuration.nix
          ];
        };

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
