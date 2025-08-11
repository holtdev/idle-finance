#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script to prepare a Linux host to run Golem provider
# - Checks CPU virtualization flags
# - Installs KVM/libvirt and loads modules
# - Ensures /dev/kvm exists and is accessible
# - Installs Golem provider (interactive by default; non-interactive if env set)
# - Adds ~/.local/bin to PATH
# - Installs Idle Finance Desktop App
# - Verifies installation and prints a summary

# Configurable via environment variables
: "${GOLEM_NODE_NAME:=idle-finance-node}"
: "${GOLEM_WALLET:=}"            # Optional 0x... If set and NONINTERACTIVE=1, install is automated
: "${NONINTERACTIVE:=1}"         # Set 0 to allow interactive prompts in golem installer
: "${AUTO_CONFIRM:=0}"           # Set 1 to skip confirmation prompts
: "${INSTALL_IDLE_FINANCE:=1}"   # Set 0 to skip Idle Finance app installation
: "${IDLE_FINANCE_VERSION:=2.1}" # Version to install
: "${PREFER_APPIMAGE:=}"         # Set to "1" to prefer AppImage, "0" for .deb, or leave empty to ask

log()  { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
err()  { echo -e "[ERROR] $*" >&2; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }; }

confirm() {
  if [ "${AUTO_CONFIRM}" = "1" ]; then
    log "Auto-confirming: $1"
    return 0
  fi
  echo -n "$1 (y/N): "
  read -r response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

need_sudo() {
  if sudo -n true 2>/dev/null; then SUDO=sudo; else SUDO=sudo; fi
}

detect_pkg_mgr() {
  if command -v apt-get >/dev/null 2>&1; then PKG=apt; return; fi
  err "Unsupported distro. This script currently supports apt-based systems (Ubuntu/Debian)."; exit 1
}

ensure_path() {
  # Ensure ~/.local/bin is in PATH for current shell and future sessions
  local bin_path="$HOME/.local/bin"
  if [[ ":$PATH:" != *":${bin_path}:"* ]]; then
    log "Adding ${bin_path} to PATH for current session"
    export PATH="${bin_path}:$PATH"
  fi
  if ! grep -qs "\.local/bin" "$HOME/.bashrc" 2>/dev/null; then
    log "Persisting PATH update in ~/.bashrc"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
}

check_virt_flags() {
  if grep -Eq '(vmx|svm)' /proc/cpuinfo; then
    log "CPU virtualization flags present"
  else
    warn "CPU virtualization flags not detected. Enable VT-x/AMD-V in BIOS/UEFI or run on supported hardware."
    if ! confirm "Continue anyway? (KVM may not work)"; then
      exit 1
    fi
  fi
}

fix_broken_ppas() {
  # Remove known broken appimagelauncher PPA if present (causes apt 404 on some systems)
  if ls /etc/apt/sources.list.d/*appimagelauncher* >/dev/null 2>&1; then
    log "Found broken appimagelauncher PPA entries that may cause apt errors"
    if confirm "Remove broken PPA entries?"; then
      log "Removing broken appimagelauncher PPA entries"
      $SUDO add-apt-repository -y -r ppa:appimagelauncher-team/stable || true
      $SUDO rm -f /etc/apt/sources.list.d/appimagelauncher-team-ubuntu-stable*.list || true
    fi
  fi
}

install_packages_apt() {
  # Check what's missing
  local missing_packages=()
  local required_packages=("curl" "expect" "ca-certificates" "qemu-kvm" "libvirt-daemon-system" "libvirt-clients" "bridge-utils" "cpu-checker")
  
  for pkg in "${required_packages[@]}"; do
    if ! dpkg -l | grep -q "^ii.*$pkg"; then
      missing_packages+=("$pkg")
    fi
  done
  
  if [ ${#missing_packages[@]} -eq 0 ]; then
    log "All required packages are already installed"
    return
  fi
  
  log "Missing packages: ${missing_packages[*]}"
  if ! confirm "Install missing packages? (requires sudo)"; then
    err "Cannot proceed without required packages"; exit 1
  fi
  
  log "Updating apt indexes"
  $SUDO apt-get update
  log "Installing base tools"
  $SUDO apt-get install -y curl expect ca-certificates
  log "Installing KVM/libvirt and helpers"
  $SUDO apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker
}

enable_kvm() {
  # Check KVM status
  local kvm_needs_setup=false
  
  if ! lsmod | grep -q "^kvm"; then
    log "KVM modules not loaded"
    kvm_needs_setup=true
  fi
  
  if [ ! -e /dev/kvm ]; then
    log "/dev/kvm device not present"
    kvm_needs_setup=true
  fi
  
  if ! id -nG "$USER" | grep -qw kvm; then
    log "User not in kvm group"
    kvm_needs_setup=true
  fi
  
  # Check if modules are configured to load at boot
  if ! grep -q "^kvm" /etc/modules 2>/dev/null; then
    log "KVM modules not configured to load at boot"
    kvm_needs_setup=true
  fi
  
  if [ "$kvm_needs_setup" = false ]; then
    log "KVM is already properly configured"
    ls -l /dev/kvm || true
    return
  fi
  
  if ! confirm "Setup KVM modules, device, and permissions? (requires sudo)"; then
    err "Cannot proceed without KVM setup"; exit 1
  fi
  
  log "Loading KVM modules"
  $SUDO modprobe kvm || true
  if grep -q GenuineIntel /proc/cpuinfo; then
    $SUDO modprobe kvm_intel || true
  else
    $SUDO modprobe kvm_amd || true
  fi

  # Make modules load at boot time
  log "Configuring KVM modules to load at boot"
  if ! grep -q "^kvm$" /etc/modules 2>/dev/null; then
    echo "kvm" | $SUDO tee -a /etc/modules > /dev/null
  fi
  
  if grep -q GenuineIntel /proc/cpuinfo; then
    if ! grep -q "^kvm_intel$" /etc/modules 2>/dev/null; then
      echo "kvm_intel" | $SUDO tee -a /etc/modules > /dev/null
    fi
  else
    if ! grep -q "^kvm_amd$" /etc/modules 2>/dev/null; then
      echo "kvm_amd" | $SUDO tee -a /etc/modules > /dev/null
    fi
  fi

  if [ ! -e /dev/kvm ]; then
    warn "/dev/kvm not present; creating device node"
    $SUDO mknod /dev/kvm c 10 232 || true
  fi

  # Group and permissions
  $SUDO groupadd -f kvm || true
  $SUDO usermod -aG kvm "$USER" || true
  $SUDO chown root:kvm /dev/kvm || true
  # Set permissive perms to avoid re-login requirement. Adjust to 660 if you prefer.
  $SUDO chmod 666 /dev/kvm || true

  # Create udev rule to ensure /dev/kvm permissions persist
  log "Creating udev rule for persistent /dev/kvm permissions"
  $SUDO tee /etc/udev/rules.d/60-kvm.rules > /dev/null << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF

  ls -l /dev/kvm || true
  log "KVM modules will now load automatically at boot"
}

install_golem() {
  if command -v golemsp >/dev/null 2>&1; then
    log "Golem already installed: $(golemsp --version 2>/dev/null || echo installed)"
    return
  fi

  log "Golem provider not found"
  if ! confirm "Install Golem provider? (this will download and run the official installer)"; then
    err "Cannot proceed without Golem provider"; exit 1
  fi

  log "Installing Golem provider"
  if [ "${NONINTERACTIVE}" = "1" ] && [ -n "${GOLEM_WALLET}" ]; then
    # Non-interactive using expect
    expect <<'EOF'
set timeout -1
spawn bash -c "curl -sSf https://join.golem.network/as-provider | bash -"
expect {
  -re ".*Do you accept the terms and conditions.*" { send "yes\r"; exp_continue }
  -re ".*Do you agree to augment stats.golem.network.*" { send "allow\r"; exp_continue }
  -re ".*Node name.*" { send "'$GOLEM_NODE_NAME'\r"; exp_continue }
  -re ".*Ethereum mainnet wallet address.*" { send "'$GOLEM_WALLET'\r"; exp_continue }
  -re ".*Price GLM per hour.*" { send "0.025\r"; exp_continue }
  eof
}
EOF
  else
    warn "Running Golem installer interactively (set GOLEM_WALLET and NONINTERACTIVE=1 to auto-answer)"
    bash -c "curl -sSf https://join.golem.network/as-provider | bash -"
  fi

  if ! command -v golemsp >/dev/null 2>&1; then
    err "golemsp not found after install. Check installer logs."; exit 1
  fi
}

install_idle_finance_app() {
  log "Installing Idle Finance Desktop App"
  
  # Check if already installed
  if command -v idle-finance >/dev/null 2>&1 || [ -f "/opt/Idle-Finance/idle-finance" ] || [ -f "/usr/local/bin/idle-finance" ]; then
    log "Idle Finance app already installed"
    return
  fi
  
  if ! confirm "Install Idle Finance Desktop App (v${IDLE_FINANCE_VERSION})?"; then
    log "Skipping Idle Finance app installation"
    return
  fi
  
  # Ask user for preference if not set
  local prefer_appimage="${PREFER_APPIMAGE}"
  if [ -z "$prefer_appimage" ]; then
    echo
    echo "Choose installation method:"
    echo "1) .deb package (recommended for Ubuntu/Debian - better integration)"
    echo "2) AppImage (portable, works on any Linux)"
    echo
    while true; do
      echo -n "Enter choice (1 or 2): "
      read -r choice
      case $choice in
        1) prefer_appimage="0"; break ;;
        2) prefer_appimage="1"; break ;;
        *) echo "Please enter 1 or 2";;
      esac
    done
  fi
  
  # Create temp directory
  local temp_dir=$(mktemp -d)
  cd "$temp_dir"
  
  if [ "$prefer_appimage" = "1" ]; then
    # Install AppImage first
    install_idle_finance_appimage
  else
    # Try .deb first, fallback to AppImage
    if ! install_idle_finance_deb; then
      warn "Falling back to AppImage installation..."
      install_idle_finance_appimage
    fi
  fi
  
  cd - > /dev/null
  rm -rf "$temp_dir"
}

install_idle_finance_deb() {
  log "Attempting to install .deb package..."
  local deb_url="https://github.com/skillDeCoder/idle-finance-v2/releases/download/v${IDLE_FINANCE_VERSION}/idle-finance_2.1.1_amd64.deb"
  
  if curl -fsSL "$deb_url" -o idle-finance.deb; then
    log "Downloaded .deb package, installing..."
    if $SUDO dpkg -i idle-finance.deb 2>/dev/null || $SUDO apt-get install -f -y && $SUDO dpkg -i idle-finance.deb; then
      log "Idle Finance app installed successfully via .deb package"
      return 0
    else
      warn "Failed to install .deb package"
      return 1
    fi
  else
    warn "Could not download .deb package"
    return 1
  fi
}

install_idle_finance_appimage() {
  log "Downloading AppImage..."
  local appimage_url="https://github.com/skillDeCoder/idle-finance-v2/releases/download/v${IDLE_FINANCE_VERSION}/Idle-Finance-2.1.0-fixed.AppImage"
  
  if curl -fsSL "$appimage_url" -o idle-finance.AppImage; then
    log "Downloaded AppImage, setting up..."
    chmod +x idle-finance.AppImage
    
    # Install to /usr/local/bin
    $SUDO mv idle-finance.AppImage /usr/local/bin/idle-finance
    log "Idle Finance AppImage installed to /usr/local/bin/idle-finance"
    
    # Create desktop shortcut
    $SUDO tee /usr/share/applications/idle-finance.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Idle Finance
Comment=Idle Finance Desktop Application
Exec=/usr/local/bin/idle-finance
Icon=idle-finance
Terminal=false
Type=Application
Categories=Finance;Network;
EOF
    
    log "Desktop shortcut created"
    return 0
  else
    err "Failed to download Idle Finance AppImage"
    return 1
  fi
}

verify_summary() {
  log "Verification summary"
  if command -v golemsp >/dev/null 2>&1; then
    echo " - golemsp path: $(command -v golemsp)"
    echo " - golemsp version: $(golemsp --version 2>/dev/null || echo n/a)"
  else
    echo " - golemsp: NOT FOUND in PATH"
  fi

  if [ -e /dev/kvm ]; then
    echo " - /dev/kvm: $(ls -l /dev/kvm)"
  else
    echo " - /dev/kvm: MISSING"
  fi

  if id -nG "$USER" | grep -qw kvm; then
    echo " - user in group 'kvm': YES"
  else
    echo " - user in group 'kvm': NO (you may need to log out/in)"
  fi

  echo " - PATH includes ~/.local/bin: $(echo "$PATH" | grep -q "$HOME/.local/bin" && echo YES || echo NO)"
}

main() {
  # Show banner if figlet is available
  if command -v figlet >/dev/null 2>&1; then
    echo
    figlet -f slant "GOLEM BOOTSTRAP" 2>/dev/null || figlet "GOLEM BOOTSTRAP" 2>/dev/null || echo "=== GOLEM HOST BOOTSTRAP ==="
    echo
  else
    echo
    echo "=== GOLEM HOST BOOTSTRAP ==="
    echo
  fi
  
  log "This script will check and install all requirements for running Golem provider"
  log "Set AUTO_CONFIRM=1 to skip confirmation prompts"
  echo
  
  need_sudo
  detect_pkg_mgr
  require_cmd curl
  ensure_path
  check_virt_flags
  fix_broken_ppas
  install_packages_apt
  enable_kvm
  install_golem
  verify_summary
  log "Done. If you were added to group 'kvm', you may need to log out/in."
  
  # Install Idle Finance app if requested
  if [ "${INSTALL_IDLE_FINANCE}" = "1" ]; then
    install_idle_finance_app
  fi
  
  # Always show completion banner
  echo
  if command -v figlet >/dev/null 2>&1; then
    figlet -f slant "SUCCESS!" 2>/dev/null || figlet "SUCCESS!" 2>/dev/null || echo "=== SUCCESS! ==="
  else
    echo "=== SUCCESS! ==="
  fi
  echo
}

main "$@"
