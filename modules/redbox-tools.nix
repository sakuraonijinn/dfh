# Redbox — combined FRP bypass + red team pentesting toolchain.
# Replaces the old frpbox (MediaTek-only). Runs as a libvirt/QEMU VM on hub.
# Import this on any host that needs both device unlocking AND app pentesting.
{ config, pkgs, lib, ... }:

{
  nixpkgs.overlays = [ (final: prev: {
    mtkclient = final.python3.pkgs.buildPythonPackage {
      pname = "mtkclient";
      version = "2.1.4";
      src = final.fetchFromGitHub {
        owner = "bkerler";
        repo = "mtkclient";
        rev = "0542a8729993000661e2325e838217ee754d1632";
        sha256 = "sha256-sl6u9HbJmUCuAeKhd1qwpceBqa88nekgpTVXvZ6Rd4o=";
      };
      pyproject = true;
      nativeBuildInputs = [ final.python3.pkgs.hatchling ];
      propagatedBuildInputs = with final.python3.pkgs; [
        pyusb
        pycryptodome
        pycryptodomex
        colorama
        pyserial
        tqdm
      ];
      dontCheckRuntimeDeps = true;
      pythonImportsCheck = [ ];
    };
  }) ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="0e8d", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1d6b", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    # ── MediaTek / MTK flashing ──
    mtkclient
    libusb1
    usbutils
    android-tools

    # ── FRP / screen lock bypass tools ──
    gcc
    pkg-config
    unzip
    nodejs
    python3

    # ── Android / APK workflow ──
    apktool
    jadx
    apksigner
    jdk17
    dex2jar
    enjarify

    # ── Frida / dynamic instrumentation ──
    frida-tools
    (python3.withPackages (p: with p; [
      frida-python
      androguard
      requests
      colorama
      rich
      scapy
      pycryptodome
    ]))

    # ── Network / proxy ──
    mitmproxy
    tcpdump
    nmap
    socat

    # ── Utilities ──
    git
    curl
    wget
    tree
    htop
    ripgrep
    fd
    jq
    file
    p7zip
    browsh
  ];

  # Ephemeral shell for heavy pentest tools — pulled on demand, GC'd on exit.
  environment.interactiveShellInit = ''
    redbox-frp() {
      echo "[+] FRP bypass toolkit..."
      echo "  frp-bypass-apk   — push bypass APK via ADB"
      echo "  frp-bypass-adb   — ADB shell FRP removal"
      echo "  frp-drfone       — launch Dr.Fone (needs license)"
      echo "  frp-check-model — detect device model + Android version"
    }

    pentest-shell() {
      echo "[+] Entering ephemeral shell with heavy pentest tools..."
      nix shell \
        nixpkgs#metasploit nixpkgs#hashcat nixpkgs#john nixpkgs#hydra \
        nixpkgs#sqlmap nixpkgs#nikto nixpkgs#gobuster nixpkgs#ffuf \
        nixpkgs#whatweb nixpkgs#bettercap nixpkgs#aircrack-ng \
        nixpkgs#wireshark nixpkgs#recon-ng nixpkgs#theharvester \
        nixpkgs#amass nixpkgs#subfinder nixpkgs#masscan nixpkgs#dnsrecon
    }
  '';
}
