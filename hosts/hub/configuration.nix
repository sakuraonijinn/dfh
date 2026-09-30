# GUI hub. Internal 30G disk — has its own sdcard-store for /nix/store.
# Also the libvirt/QEMU host for redbox, iosbox, forensicsbox VMs.
{ config, pkgs, lib, ... }:

{
  networking.hostName = "phone-lab";

  sdcardStore.uuid = "a29fbc70-66c5-4131-b3fd-74866da78df6";

  users.users.sakura = {
    isNormalUser = true;
    extraGroups = [
      "wheel" "networkmanager" "adbusers" "video" "input" "docker" "wireshark"
    ];
    shell = pkgs.bash;
    # Generate with: mkpasswd -m sha-512
    # Save the hash OUTSIDE the nix store: /etc/nixos/secrets/sakura.hash
    # (chmod 600, root-owned).
    hashedPasswordFile = "/etc/nixos/secrets/sakura.hash";
  };

#  virtualisation.docker = {
 #   enable = true;
    # Docker images live outside the Nix store and aren't touched by
    # nix.gc — on a 30G disk they're the most likely thing to blow your
    # budget. Point at bigger/separate storage if you have it:
    # daemon.settings.data-root = "/mnt/bigger-disk/docker";
    # Otherwise: `docker system prune -af --volumes` regularly.
 # };

  environment.systemPackages = with pkgs; [
    # ── Core Android / APK workflow ──
    apktool jadx apksigner android-tools jdk17
    frida-tools
    mitmproxy

    # ── Core recon ──
    nmap tcpdump

    bluez bluez-tools

    (python3.withPackages (p: with p; [
      frida-python androguard pwntools requests colorama rich
      scapy impacket pycryptodome paramiko beautifulsoup4 flask
    ]))

    # ── General utilities not already in common.nix ──
    neovim vim opencode file binutils

    # ── Genymotion / Android emulator ──
    # Temporarily removed while phone-lab is first built: both pull large
    # unfree closures and the GUI stack is what we want working first.
    # Re-add `genymotion` (packaged locally in modules/genymotion.nix, wired
    # into the flake as packages.default) and `virtualbox` here once the
    # base system boots. See modules/genymotion.nix.
  ];

  # ── Convenience shell functions ──
  environment.etc."nixos/shell-functions".text = ''
    adb-pull-apk() {
      local path="$1"
      [ -z "$path" ] && echo "Usage: adb-pull-apk <package>" && return 1
      local pkg="$2"
      adb pull "$path" "$pkg.apk" && echo "[+] Saved: $pkg.apk"
    }

    apk-install() {
      if [ -z "$1" ]; then echo "Usage: apk-install <patched.apk> [package]"; return 1; fi
      local pkg="$2"
      [ -n "$pkg" ] && adb uninstall "$pkg" 2>/dev/null
      adb install -r "$1"
    }

    frida-run() {
      if [ -z "$1" ] || [ -z "$2" ]; then echo "Usage: frida-run <package> <script.js>"; return 1; fi
      [ ! -f "$2" ] && echo "[-] Script not found: $2" && return 1
      frida -U -f "$1" -l "$2" --no-pause
    }

    proxy-on() {
      echo "[+] Starting mitmproxy on 8080..."
      mitmproxy --listen-port 8080 --showhost &
      sleep 1
      adb reverse tcp:8080 tcp:8080 2>/dev/null
      adb shell settings put global http_proxy 127.0.0.1:8080
      echo "[+] Proxy active — install mitm CA on device: http://mitm.it"
    }
    proxy-off() {
      adb shell settings put global http_proxy :0
      adb reverse --remove tcp:8080 2>/dev/null
      pkill mitmproxy 2>/dev/null
      echo "[+] Proxy stopped"
    }

    scan() {
      if [ -z "$1" ]; then echo "Usage: scan <target>"; return 1; fi
      sudo nmap -sV -sC -O "$1"
    }

    # Ephemeral shell for the heavy/occasional tools — not permanently
    # installed, eligible for GC as soon as you exit.
    pentest-shell() {
      echo "[+] Entering ephemeral shell with heavy pentest tools..."
      nix shell \
        nixpkgs#metasploit nixpkgs#hashcat nixpkgs#john nixpkgs#hydra \
        nixpkgs#sqlmap nixpkgs#nikto nixpkgs#gobuster nixpkgs#ffuf \
        nixpkgs#whatweb nixpkgs#bettercap nixpkgs#aircrack-ng \
        nixpkgs#wireshark nixpkgs#recon-ng nixpkgs#theharvester \
        nixpkgs#amass nixpkgs#subfinder nixpkgs#masscan nixpkgs#dnsrecon \
        nixpkgs#dex2jar nixpkgs#enjarify
    }

    cap() {
      if [ -z "$1" ]; then echo "Usage: cap <target-ip>"; return 1; fi
      sudo bettercap -eval "set arp.spoof.targets $1; arp.spoof on; net.sniff on"
    }

    redbox-start() {
      echo "[+] Starting Redbox VM..."
      sudo virsh start redbox 2>/dev/null || sudo virsh start redbox
    }

    redbox-stop() {
      echo "[+] Stopping Redbox VM..."
      sudo virsh destroy redbox 2>/dev/null
    }

    redbox-console() {
      sudo virsh console redbox
    }
  '';
}
