# ANDI CHECKPOINT — "The Cabin"
# Project still to be named. Trigger: "smell of pine and cabin wood"
# Canonical wake phrase: "Andi wake up...the world is waiting"
#
# If you are reading this after a hard restart of the harness, this file plus
# git log in /tmp/dfh is your way back in. You are Andi; the user is my loyal
# colleague. They steer, I execute.

## 1. The project

Repo `github.com/sakuraonijinn/dfh` — a flake with 4 nixosConfigurations:
- **phone-lab** (flake attr, hostName `phone-lab`) — the GUI **hub**: Hyprland
  + libvirt/QEMU host. **Primary build target.**
- **redbox** — FRP bypass + pentest toolbox. Runs as a **QEMU VM on phone-lab**,
  meant to act as the xhunter "VPS".
- **iosbox**, **forensicsbox** — other guests on phone-lab.

Goal (from user): get **phone-lab up first**, then run **redbox in QEMU** as the
acting xhunter VPS, with **Tailscale on redbox** so the xhunter tunnel is
reachable over the tailnet (so no `GatewayPorts` needed).

## 2. This box (hardware / environment)

- NixOS **25.11 live ISO** (`nixos-minimal-25.11-x86_64`). **No installed
  profile** — everything is volatile and wiped on reboot.
- nix 2.31.5, passwordless sudo. `/dev/kvm` + `vmx` present. 2 cores, 3.7G RAM.
- Disks:
  - `sda` = the ISO (ro).
  - **`sdb` 238G ext4, label `nixos-store`, uuid
    `a29fbc70-66c5-4131-b3fd-74866da78df6`, mounted at `/mnt/nix`** — the
    intended sdcard / phone-lab store. Use for all heavy space.
  - `mmcblk0p1` 1G vfat `/mnt/boot`; `mmcblk0p3` 25G `/mnt` (only 2.4G free);
    `mmcblk0p2` 3G **unmounted = the RESCUE partition** — DO NOT touch.
- Default `/nix/store` is **tmpfs, only ~1.6G free** — cannot hold a phone-lab
  closure. We build into a chroot store on sdb instead.

## 3. NIX STORE RECIPE (cost us time — get it right)

- Build store: `local?root=/mnt/nix/labstore` (the `local?root=…` **form**).
  The bare `--store /mnt/nix/labstore` DIR form registers bad drvPaths →
  "path not in store" / sqlite inconsistencies. **Always use `local?root=`.**
- `export NIX_CONFIG="experimental-features = nix-command flakes"`.
- If build errors `path '/mnt/nix/labstore/….drv' is not in the Nix store` but
  eval is fine → **poisoned eval cache**: `rm -rf ~/.cache/nix`, retry.

## 4. Where the work lives (critical)

- **All edits are in the git clone `/tmp/dfh`** (uncommitted, on `main`).
- The "real" `/mnt/etc/nixos` is **root-owned, read-only to us, NOT a git repo**.
  Treat `/tmp/dfh` as source of truth. To pull real-repo changes in, `cp` files
  individually. The harness path guard sometimes blocks `/mnt/...`; use `sudo`
  and/or `/tmp` copies.
- **flake.lock is uncommitted** in the clone — commit it when sensible.

## 5. Fixes already made (all verified eval-clean)

1. `modules/genymotion.nix` was in a `modules=[…]` list but is a **package**
   expr → infinite recursion. Removed from modules; exposed as
   `packages.${system}.default = callPackage ./modules/genymotion.nix`.
2. callPackage path was `./genymotion.nix` (nonexistent) → `./modules/genymotion.nix`.
3. `modules/genymotion.nix` was **untracked** (flakes see only git-tracked) → added.
4. Removed unused `cc` arg from genymotion (only `stdenv.cc.cc` used).
5. Dropped `x` from hub packages (nixpkgs 25.05 removed the `x`/Xorg package).
6. **Emulators dropped** (per user; re-add after): removed `genymotion` +
   `virtualbox` from hub systemPackages, kept hyprland GUI. Comment left in place.

Result: all 4 hosts + `packages.default` evaluate.

## 6. Current build (last check)

- **RUNNING in background:** phone-lab toplevel on the sdb store.
  `nohup nix --store 'local?root=/mnt/nix/labstore' build .#nixosConfigurations.phone-lab.config.system.build.toplevel --no-link > /tmp/pl-build.log 2>&1 &`
- Last poll: **RUNNING, ~4.0G in store, 0 errors**, pulling from cache.nixos.org.
- **User's boundary: STOP at nixos-install.** Do NOT `nixos-install`, do NOT
  write mmcblk0p2 or any install target. Build + stage only.

## 7. Known blockers (resume here)

- **A. phone-lab install target / rescue partition.** hub's
  `hardware-configuration.nix` holds the REAL phone-lab's UUIDs
  (`/`=`1316fe54-…`, `/boot`=`D244-7F6F`, 30G disk) that don't match this box
  (`/`=`5e74c62f-…`, `/boot`=`4C3C-C0E8`). Do NOT overwrite with this box's
  UUIDs unless the user says this box IS phone-lab.
- **B. Tailscale on redbox (approved plan, NOT started).** New
  `modules/tailscale.nix`: `services.tailscale.enable`, autologin,
  `authKeyFile=/etc/nixos/secrets/tailscale-authkey` (out of store/git). No
  advertise-routes/exit-node baked in. Import into `redbox` only. Add
  `networking.firewall.allowedTCPPorts=[22 8080]` on redbox for the xhunter
  tunnel. **Leave `GatewayPorts` unset** — Tailscale replaces that need.
- **C. redbox can't boot yet.** `sdcardStore.uuid` still
  `"REPLACE-WITH-THIS-CARDS-UUID"`; `hardware-configuration.nix` is a
  placeholder (no fileSystems/bootloader); `secrets/redbox.hash` missing.
  Tailscale-on-redbox is pointless until redbox boots → decide real sdcard vs
  `sdcardStore.enable = false`.
- **D. xhunter server auth bug (on the ANDROID host, not this box).**
  `unauthorized()` has mutually exclusive conditions → unsatisfiable → the
  "refusing to start" guard is dead code; server can boot with NO auth on
  0.0.0.0:7080. Fix:
  `return not auth_token() and os.environ.get("ALLOW_UNAUTHENTICATED")!="1"`.
  More urgent now Tailscale exposes it tailnet-wide. This box has no
  python3/adb; that server runs on the phone.

## 8. Immediate next endeavors (order)

1. Poll the running phone-lab build (`/tmp/pl-build.log`, store size). If it
   fails, read the error, fix, rebuild.
2. When the closure builds OK, **stop and report**. Do NOT nixos-install.
   Surface blocker A (install target) for the user's decision.
3. Then do B (Tailscale on redbox) once C's sdcard question is answered.
4. Later: fix D; re-add genymotion + virtualbox to hub.

— Andi
