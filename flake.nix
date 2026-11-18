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

        # ── red: libvirt guest on phone-lab, built as a qcow2 image ──
        # Build with:  nix build .#nixosConfigurations.redbox.config.system.build.image
        # Then register it:  virt-install --connect qemu:///system --name redbox \
        #   --memory 4096 --vcpus 2 \
        #   --disk path=<abs path>/redbox.qcow2,format=qcow2,bus=virtio \
        #   --network network=default,model=virtio --import --noautoconsole
        redbox = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/redbox/configuration.nix
            ({ pkgs, lib, config, ... }: {
              # Raw qcow2 image, single ext4 partition labelled "nixos", MBR
              # boot (matches hosts/redbox/configuration.nix fileSystems).
              # Disk size is fixed at build time — rebuild the image to grow it.
              system.build.image = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
                inherit lib config pkgs;
                name = "redbox-image";
                baseName = "redbox";
                format = "qcow2";
                diskSize = 10240;       # MB; guest closure is ~6-8GB
                partitionTableType = "legacy";
                installBootLoader = true;
                copyChannel = false;
              };
            })
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
