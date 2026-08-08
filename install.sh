#!/usr/bin/env bash
# Clean install of the phone-lab flake onto a fresh disk.
#
# RUN THIS FROM THE NIXOS INSTALLER ISO, booted on the target machine.
# It WIPES the disk you specify. There is a typed confirmation gate —
# it will not proceed on assumption or a single "y".
#
# Usage:
#   curl -L <your-hosted-url-for-this-script> | bash -s -- /dev/nvme0n1
# or, run locally after copying it + the nixcfg repo onto a USB stick:
#   bash install.sh /dev/sda
#
# Either way, the nixcfg repo (flake.nix, modules/, hosts/, etc.) must be
# reachable — either:
#   (a) sitting next to this script in the same directory, or
#   (b) fetched separately first: `git clone <your-repo-url> nixcfg`
# This script does NOT fetch the flake itself — only Anthropic can't host
# it for you, so point it at wherever you actually keep it (a private
# git remote, a gist, or a USB stick).

set -euo pipefail

DISK="${1:-}"
HOST="${2:-phone-lab}"
NIXCFG_SRC="${NIXCFG_SRC:-$(dirname "$(readlink -f "$0")")/nixcfg}"

if [ -z "$DISK" ]; then
  echo "Usage: $0 /dev/sdX [host-flake-attribute]"
  echo "  e.g.: $0 /dev/nvme0n1 phone-lab"
  exit 1
fi

if [ ! -b "$DISK" ]; then
  echo "error: $DISK is not a block device. Check 'lsblk' and try again."
  exit 1
fi

if [ ! -f "$NIXCFG_SRC/flake.nix" ]; then
  echo "error: no flake.nix found at $NIXCFG_SRC"
  echo "Set NIXCFG_SRC=/path/to/nixcfg or place a 'nixcfg' folder next to this script."
  exit 1
fi

echo "══════════════════════════════════════════════════════════"
echo " THIS WILL DESTROY ALL DATA ON: $DISK"
echo "══════════════════════════════════════════════════════════"
lsblk "$DISK"
echo
echo "Type the device path exactly ($DISK) to confirm, anything else aborts:"
read -r CONFIRM
if [ "$CONFIRM" != "$DISK" ]; then
  echo "Confirmation did not match. Aborting — nothing was touched."
  exit 1
fi

echo "[+] Partitioning $DISK (GPT: 512M ESP + rest as root)..."
parted -s "$DISK" -- mklabel gpt
parted -s "$DISK" -- mkpart ESP fat32 1MiB 513MiB
parted -s "$DISK" -- set 1 esp on
parted -s "$DISK" -- mkpart root ext4 513MiB 100%

# NVMe devices need a 'p' before the partition number; sdX devices don't.
if [[ "$DISK" == *nvme* ]]; then
  BOOT_PART="${DISK}p1"
  ROOT_PART="${DISK}p2"
else
  BOOT_PART="${DISK}1"
  ROOT_PART="${DISK}2"
fi

echo "[+] Formatting..."
mkfs.fat -F32 -n boot "$BOOT_PART"
mkfs.ext4 -L nixos "$ROOT_PART"

echo "[+] Mounting..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot
mount "$BOOT_PART" /mnt/boot

echo "[+] Copying flake into /mnt/etc/nixos..."
mkdir -p /mnt/etc/nixos
cp -r "$NIXCFG_SRC"/. /mnt/etc/nixos/

echo "[+] Generating hardware-configuration.nix for this machine..."
nixos-generate-config --root /mnt --show-hardware-config \
  > "/mnt/etc/nixos/hosts/${HOST%%-*}/hardware-configuration.nix" 2>/dev/null || \
nixos-generate-config --root /mnt --show-hardware-config \
  > "/mnt/etc/nixos/hosts/hub/hardware-configuration.nix"
echo "    (double-check the right hosts/<name>/hardware-configuration.nix got this — see note below)"

echo "[+] Setting up secrets dir (password hash goes here, not in the flake)..."
mkdir -p /mnt/etc/nixos/secrets
echo "    Run 'mkpasswd -m sha-512' now and paste the result:"
read -r -s PW_HASH
echo "$PW_HASH" > /mnt/etc/nixos/secrets/sakura.hash
chmod 600 /mnt/etc/nixos/secrets/sakura.hash

echo "[+] Installing NixOS via the flake (this will take a while)..."
nixos-install --flake "/mnt/etc/nixos#${HOST}" --no-root-passwd

echo "══════════════════════════════════════════════════════════"
echo " Done. Remove the install media and reboot:"
echo "   reboot"
echo "══════════════════════════════════════════════════════════"
