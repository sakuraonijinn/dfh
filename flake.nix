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
