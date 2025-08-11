#!/usr/bin/env bash
set -euo pipefail

# Configurable via environment variables
: "${GOLEM_NODE_NAME:=idle-finance-node}"
: "${GOLEM_WALLET:=}"            # Optional 0x... If set and NONINTERACTIVE=1, install is automated
: "${NONINTERACTIVE:=1}"         # Set 0 to allow interactive prompts in golem installer
: "${AUTO_CONFIRM:=0}"           # Set 1 to skip confirmation prompts
: "${INSTALL_IDLE_FINANCE:=1}"   # Set 0 to skip Idle Finance app installation
: "${IDLE_FINANCE_VERSION:=2.1}" # Version to install
: "${PREFER_APPIMAGE:=}"         # Set to "1" to prefer AppImage, "0" for .deb, or leave empty to ask

# =============================================================================
# 🎨 SLEEK MODERN DESIGN SYSTEM
# =============================================================================

# Modern color palette with better contrast
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Sleek gradient colors
GRADIENT_BLUE='\033[38;5;39m'
GRADIENT_PURPLE='\033[38;5;99m'
GRADIENT_PINK='\033[38;5;213m'
GRADIENT_ORANGE='\033[38;5;208m'
GRADIENT_GREEN='\033[38;5;46m'

# Status colors
SUCCESS='\033[38;5;46m'
WARNING='\033[38;5;208m'
ERROR='\033[38;5;196m'
INFO='\033[38;5;39m'
STEP='\033[38;5;99m'

# =============================================================================
# 🎭 MODERN UI COMPONENTS
# =============================================================================

# Sleek card component with rounded corners
sleek_card() {
    local title="$1"
    local content="$2"
    local color="${3:-$GRADIENT_BLUE}"
    
    echo
    printf "${color}╭─────────────────────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${color}│${RESET} ${BOLD}${WHITE}%s${RESET}%*s${color} ${RESET}\n" "$title" $((67 - ${#title})) ""
    printf "${color}├─────────────────────────────────────────────────────────────────────────┤${RESET}\n"
    printf "${color}│${RESET} %s%*s${color} ${RESET}\n" "$content" $((67 - ${#content})) ""
    printf "${color}╰─────────────────────────────────────────────────────────────────────────╯${RESET}\n"
    echo
}

# Modern step indicator with progress
modern_step() {
    local step="$1"
    local total="$2"
    local title="$3"
    local status="${4:-}"
    
    local progress=$((step * 100 / total))
    local bar_width=40
    local filled=$((bar_width * step / total))
    local empty=$((bar_width - filled))
    
    echo
    printf "${STEP}┌─ STEP ${BOLD}%d${RESET}/${STEP}${BOLD}%d${RESET}${STEP}───────────────────────────────────────────────────────────┐${RESET}\n" "$step" "$total"
    printf "${STEP}│${RESET} ${BOLD}${WHITE}%s${RESET}%*s${STEP} │${RESET}\n" "$title" $((67 - ${#title})) ""
    
    if [ -n "$status" ]; then
        printf "${STEP}│${RESET} ${INFO}%s${RESET}%*s${STEP} │${RESET}\n" "$status" $((67 - ${#status})) ""
    fi
    
    printf "${STEP}│${RESET} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%d%%${RESET}%*s${STEP} │${RESET}\n" "$progress" $((29 - 8)) ""
    printf "${STEP}└─────────────────────────────────────────────────────────────────────┘${RESET}\n"
    echo
}

# Sleek banner with gradient text
sleek_banner() {
    local text="$1"
    local gradient_start="${2:-$GRADIENT_BLUE}"
    local gradient_end="${3:-$GRADIENT_PURPLE}"
    
    echo
    printf "${gradient_start}╭─────────────────────────────────────────────────────────────────────────╮${RESET}\n"
    printf "${gradient_start}│${RESET}%*s${BOLD}${gradient_end}%s${RESET}%*s${gradient_start} ${RESET}\n" $((36 - ${#text} / 2)) "" "$text" $((36 - ${#text} / 2)) ""
    printf "${gradient_start}╰─────────────────────────────────────────────────────────────────────────╯${RESET}\n"
    printf "\n"
    echo
}

# Modern success message
success_msg() {
    printf "${SUCCESS}✓ %s${RESET}\n" "$1"
}

# Modern warning message
warning_msg() {
    printf "${WARNING}⚠ %s${RESET}\n" "$1"
}

# Modern error message
error_msg() {
    printf "${ERROR}✗ %s${RESET}\n" "$1"
}

# Modern info message
info_msg() {
    printf "${INFO}ℹ %s${RESET}\n" "$1"
}

# Sleek loading animation
sleek_loading() {
    local message="$1"
    local duration="${2:-3}"
    
    printf "${INFO}%s${RESET}" "$message"
    for i in $(seq 1 $duration); do
        sleep 0.3
        printf "."
    done
    printf "${RESET}\n"
}

# =============================================================================
# 🎨 MODERN BANNER SYSTEM
# =============================================================================

# Sleek startup banner
show_startup_banner() {
    clear
    echo
    
    # Show figlet if available
    if command -v figlet >/dev/null 2>&1; then
        if [ -n "$COLOR_TOOL" ] && command -v "$COLOR_TOOL" >/dev/null 2>&1; then
            case "$COLOR_TOOL" in
                "rainbow")
                    figlet -f slant "IDLE FINANCE" | rainbow
                    ;;
                "ccat")
                    figlet -f slant "IDLE FINANCE" | ccat
                    ;;
                "bat")
                    figlet -f slant "IDLE FINANCE" | bat --style=plain --language=text
                    ;;
                "highlight")
                    figlet -f slant "IDLE FINANCE" | highlight --out-format=ansi
                    ;;
                "grc")
                    figlet -f slant "IDLE FINANCE" | grc -es --colour=auto
                    ;;
            esac
        else
            figlet -f slant "IDLE FINANCE"
        fi
        echo
    fi
    
    sleek_banner "🚀 IDLE FINANCE BOOTSTRAP 🚀" "$GRADIENT_BLUE" "$GRADIENT_PURPLE"
    
    sleek_loading "Initializing system" 3
    echo
}

# Sleek success banner
show_success_banner() {
    echo
    sleek_banner "🎉 BOOTSTRAP COMPLETED SUCCESSFULLY! 🎉" "$GRADIENT_GREEN" "$GRADIENT_BLUE"
    
    sleek_card "SUCCESS" "Your Golem provider is ready to earn rewards!" "$GRADIENT_GREEN"
}

# =============================================================================
# ⏱️ ENHANCED TIMING SYSTEM
# =============================================================================

declare -A TIMERS
declare -A TIMER_STARTS

start_timer() {
    local timer_name="$1"
    TIMER_STARTS["$timer_name"]=$(date +%s)
    TIMERS["$timer_name"]=$(date '+%H:%M:%S')
    printf "${STEP}⏱ Started %s at %s${RESET}\n" "$timer_name" "${TIMERS[$timer_name]}"
}

end_timer() {
    local timer_name="$1"
    local end_time=$(date +%s)
    local start_time="${TIMER_STARTS[$timer_name]}"
    local duration=$((end_time - start_time))
    local start_time_str="${TIMERS[$timer_name]}"
    local end_time_str=$(date '+%H:%M:%S')
    
    printf "${SUCCESS}⏱ Completed %s in %ds (%s → %s)${RESET}\n" "$timer_name" "$duration" "$start_time_str" "$end_time_str"
}

# =============================================================================
# 🔧 UTILITY FUNCTIONS
# =============================================================================

require_cmd() { 
    command -v "$1" >/dev/null 2>&1 || { 
        error_msg "Missing command: $1"
        exit 1
    }
}

confirm() {
    if [ "${AUTO_CONFIRM}" = "1" ]; then
        info_msg "Auto-confirming: $1"
        return 0
    fi
    
    printf "${WARNING}❓ %s${RESET} ${BOLD}(y/N):${RESET} " "$1"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

need_sudo() {
    if sudo -n true 2>/dev/null; then 
        SUDO=sudo
    else 
        SUDO=sudo
    fi
}

detect_pkg_mgr() {
    if command -v apt-get >/dev/null 2>&1; then 
        PKG=apt
        return
    fi
    error_msg "Unsupported distro. This script currently supports apt-based systems (Ubuntu/Debian)."
    exit 1
}

ensure_path() {
    local bin_path="$HOME/.local/bin"
    if [[ ":$PATH:" != *":${bin_path}:"* ]]; then
        info_msg "Adding ${bin_path} to PATH for current session"
        export PATH="${bin_path}:$PATH"
    fi
    if ! grep -qs "\.local/bin" "$HOME/.bashrc" 2>/dev/null; then
        info_msg "Persisting PATH update in ~/.bashrc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
}

# =============================================================================
# 🔍 SYSTEM CHECKS
# =============================================================================

check_virt_flags() {
    modern_step 1 7 "Checking CPU Virtualization Support" "Verifying hardware capabilities..."
    
    if grep -Eq '(vmx|svm)' /proc/cpuinfo; then
        success_msg "CPU virtualization flags present"
    else
        warning_msg "CPU virtualization flags not detected. Enable VT-x/AMD-V in BIOS/UEFI."
        if ! confirm "Continue anyway? (KVM may not work)"; then
            exit 1
        fi
    fi
}

fix_broken_ppas() {
    modern_step 2 7 "Checking for Broken Package Sources" "Scanning package repositories..."
    
    if ls /etc/apt/sources.list.d/*appimagelauncher* >/dev/null 2>&1; then
        warning_msg "Found broken appimagelauncher PPA entries"
        if confirm "Remove broken PPA entries?"; then
            info_msg "Removing broken appimagelauncher PPA entries"
            $SUDO add-apt-repository -y -r ppa:appimagelauncher-team/stable || true
            $SUDO rm -f /etc/apt/sources.list.d/appimagelauncher-team-ubuntu-stable*.list || true
        fi
    else
        success_msg "No broken package sources detected"
    fi
}

# =============================================================================
# 📦 PACKAGE MANAGEMENT
# =============================================================================

install_packages_apt() {
    modern_step 3 7 "Installing System Packages" "Setting up required dependencies..."
    
    # Check what's missing
    local missing_packages=()
    local required_packages=("curl" "expect" "ca-certificates" "qemu-kvm" "libvirt-daemon-system" "libvirt-clients" "bridge-utils" "cpu-checker")
    
    info_msg "Checking required packages..."
    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    if [ ${#missing_packages[@]} -eq 0 ]; then
        success_msg "All required packages are already installed"
        return
    fi
    
    warning_msg "Missing packages: ${missing_packages[*]}"
    if ! confirm "Install missing packages? (requires sudo)"; then
        error_msg "Cannot proceed without required packages"
        exit 1
    fi
    
    start_timer "package_installation"
    
    info_msg "Updating package indexes..."
    $SUDO apt-get update
    
    info_msg "Installing base tools..."
    $SUDO apt-get install -y curl expect ca-certificates
    
    info_msg "Installing KVM/libvirt and helpers..."
    $SUDO apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker
    
    # Install modern UI tools
    info_msg "Installing modern UI components..."
    $SUDO apt-get install -y figlet
    
    # Install colorful text tools
    info_msg "Installing colorful text tools..."
    COLOR_TOOL=""
    
    # Try to install various colorful text alternatives
    if ! command -v rainbow >/dev/null 2>&1; then
        if command -v pipx >/dev/null 2>&1; then
            pipx install rainbow && COLOR_TOOL="rainbow"
        elif command -v pip3 >/dev/null 2>&1; then
            if $SUDO apt-get install -y python3-rainbow 2>/dev/null; then
                COLOR_TOOL="rainbow"
            fi
        fi
    else
        COLOR_TOOL="rainbow"
    fi
    
    if [ -z "$COLOR_TOOL" ]; then
        if ! command -v ccat >/dev/null 2>&1; then
            if $SUDO apt-get install -y ccat 2>/dev/null; then
                COLOR_TOOL="ccat"
            fi
        else
            COLOR_TOOL="ccat"
        fi
    fi
    
    if [ -z "$COLOR_TOOL" ]; then
        if ! command -v bat >/dev/null 2>&1; then
            if $SUDO apt-get install -y bat 2>/dev/null; then
                COLOR_TOOL="bat"
            fi
        else
            COLOR_TOOL="bat"
        fi
    fi
    
    if [ -z "$COLOR_TOOL" ]; then
        if ! command -v highlight >/dev/null 2>&1; then
            if $SUDO apt-get install -y highlight 2>/dev/null; then
                COLOR_TOOL="highlight"
            fi
        else
            COLOR_TOOL="highlight"
        fi
    fi
    
    if [ -z "$COLOR_TOOL" ]; then
        if ! command -v grc >/dev/null 2>&1; then
            if $SUDO apt-get install -y grc 2>/dev/null; then
                COLOR_TOOL="grc"
            fi
        else
            COLOR_TOOL="grc"
        fi
    fi
    
    if [ -n "$COLOR_TOOL" ]; then
        success_msg "Installed colorful text tool: $COLOR_TOOL"
    else
        warning_msg "No colorful text tools available, will use basic colors"
    fi
    
    end_timer "package_installation"
}

# =============================================================================
# 🔧 KVM SETUP
# =============================================================================

enable_kvm() {
    modern_step 4 7 "Setting up KVM Virtualization" "Configuring hardware acceleration..."
    
    # Check KVM status
    local kvm_needs_setup=false
    
    if ! lsmod | grep -q "^kvm"; then
        warning_msg "KVM modules not loaded"
        kvm_needs_setup=true
    fi
    
    if [ ! -e /dev/kvm ]; then
        warning_msg "/dev/kvm device not present"
        kvm_needs_setup=true
    fi
    
    if ! id -nG "$USER" | grep -qw kvm; then
        warning_msg "User not in kvm group"
        kvm_needs_setup=true
    fi
    
    # Check if modules are configured to load at boot
    if ! grep -q "^kvm" /etc/modules 2>/dev/null; then
        warning_msg "KVM modules not configured to load at boot"
        kvm_needs_setup=true
    fi
    
    if [ "$kvm_needs_setup" = false ]; then
        success_msg "KVM is already properly configured"
        ls -l /dev/kvm || true
        return
    fi
    
    if ! confirm "Setup KVM modules, device, and permissions? (requires sudo)"; then
        error_msg "Cannot proceed without KVM setup"
        exit 1
    fi
    
    start_timer "kvm_setup"
    
    info_msg "Loading KVM modules..."
    $SUDO modprobe kvm || true
    if grep -q GenuineIntel /proc/cpuinfo; then
        info_msg "Loading kvm_intel module..."
        $SUDO modprobe kvm_intel || true
    else
        info_msg "Loading kvm_amd module..."
        $SUDO modprobe kvm_amd || true
    fi

    # Make modules load at boot time
    info_msg "Configuring KVM modules to load at boot..."
    if ! grep -q "^kvm$" /etc/modules 2>/dev/null; then
        info_msg "Adding kvm to /etc/modules..."
        echo "kvm" | $SUDO tee -a /etc/modules > /dev/null
    fi
    
    if grep -q GenuineIntel /proc/cpuinfo; then
        if ! grep -q "^kvm_intel$" /etc/modules 2>/dev/null; then
            info_msg "Adding kvm_intel to /etc/modules..."
            echo "kvm_intel" | $SUDO tee -a /etc/modules > /dev/null
        fi
    else
        if ! grep -q "^kvm_amd$" /etc/modules 2>/dev/null; then
            info_msg "Adding kvm_amd to /etc/modules..."
            echo "kvm_amd" | $SUDO tee -a /etc/modules > /dev/null
        fi
    fi

    if [ ! -e /dev/kvm ]; then
        info_msg "Creating /dev/kvm device node..."
        $SUDO mknod /dev/kvm c 10 232 || true
    fi

    # Group and permissions
    info_msg "Setting up user permissions..."
    $SUDO groupadd -f kvm || true
    $SUDO usermod -aG kvm "$USER" || true
    $SUDO chown root:kvm /dev/kvm || true
    # Set permissive perms to avoid re-login requirement. Adjust to 660 if you prefer.
    $SUDO chmod 666 /dev/kvm || true

    # Create udev rule to ensure /dev/kvm permissions persist
    info_msg "Creating udev rule for persistent permissions..."
    $SUDO tee /etc/udev/rules.d/60-kvm.rules > /dev/null << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0666"
EOF

    end_timer "kvm_setup"
    
    success_msg "KVM setup completed!"
    ls -l /dev/kvm || true
    success_msg "KVM modules will now load automatically at boot"
}

# =============================================================================
# 🚀 GOLEM INSTALLATION
# =============================================================================

install_golem() {
    modern_step 5 7 "Installing Golem Provider" "Setting up distributed computing node..."
    
    if command -v golemsp >/dev/null 2>&1; then
        success_msg "Golem already installed: $(golemsp --version 2>/dev/null || echo installed)"
        return
    fi

    warning_msg "Golem provider not found"
    if ! confirm "Install Golem provider? (this will download and run the official installer)"; then
        error_msg "Cannot proceed without Golem provider"
        exit 1
    fi

    start_timer "golem_installation"
    
    info_msg "Installing Golem provider..."
    info_msg "Downloading Golem installer..."
    
    # Create temp directory for installation
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # Download installer with progress
    if curl -fsSL --progress-bar -o golem-installer.sh "https://join.golem.network/as-provider"; then
        success_msg "Download completed"
        chmod +x golem-installer.sh
    else
        error_msg "Failed to download Golem installer"
        cd - > /dev/null
        rm -rf "$temp_dir"
        exit 1
    fi
    
    info_msg "Running Golem installer..."
    
    if [ "${NONINTERACTIVE}" = "1" ] && [ -n "${GOLEM_WALLET}" ]; then
        # Non-interactive using expect with progress
        info_msg "Non-interactive installation mode"
        info_msg "Node name: ${GOLEM_NODE_NAME}"
        info_msg "Wallet: ${GOLEM_WALLET}"
        info_msg "Price: 0.025 GLM/hour"
        
        expect <<'EOF'
set timeout -1
spawn bash golem-installer.sh
expect {
  -re ".*Do you accept the terms and conditions.*" { 
    puts "📋 Accepting terms and conditions..."
    send "yes\r"; 
    exp_continue 
  }
  -re ".*Do you agree to augment stats.golem.network.*" { 
    puts "📊 Allowing stats collection..."
    send "allow\r"; 
    exp_continue 
  }
  -re ".*Node name.*" { 
    puts "🏷️  Setting node name..."
    send "'$GOLEM_NODE_NAME'\r"; 
    exp_continue 
  }
  -re ".*Ethereum mainnet wallet address.*" { 
    puts "💰 Setting wallet address..."
    send "'$GOLEM_WALLET'\r"; 
    exp_continue 
  }
  -re ".*Price GLM per hour.*" { 
    puts "💱 Setting price..."
    send "0.025\r"; 
    exp_continue 
  }
  -re ".*Installation completed.*" {
    puts "✅ Installation completed!"
    exp_continue
  }
  eof
}
EOF
    else
        info_msg "Interactive installation mode"
        info_msg "You will be prompted for configuration options"
        info_msg "Recommended settings:"
        info_msg "Node name: ${GOLEM_NODE_NAME}"
        info_msg "Price: 0.025 GLM/hour"
        info_msg "Accept terms and stats collection"
        echo
        bash golem-installer.sh
    fi
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    
    info_msg "Verifying installation..."
    
    # Wait a moment for installation to complete
    sleep 2
    
    if command -v golemsp >/dev/null 2>&1; then
        end_timer "golem_installation"
        success_msg "Golem provider installed successfully!"
        info_msg "Binary location: $(command -v golemsp)"
    else
        error_msg "golemsp not found after install. Check installer logs."
        exit 1
    fi
}

# =============================================================================
# 📱 IDLE FINANCE APP INSTALLATION
# =============================================================================

install_idle_finance_deb() {
    info_msg "Attempting to install .deb package..."
    local deb_url="https://github.com/holtdev/idle-finance/releases/download/v2.1/idle-finance_2.1.1_amd64.deb"
    local start_time=$(date +%s)
    
    info_msg "Download URL: $deb_url"
    info_msg "Downloading .deb package..."
    info_msg "Started at: $(date '+%H:%M:%S')"
    
    # Show loading indicator for download
    sleek_loading "📥 Downloading .deb package" 3
    
    # Download with progress
    if curl -fsSL --progress-bar "$deb_url" -o idle-finance.deb; then
        local download_time=$(date +%s)
        local download_duration=$((download_time - start_time))
        success_msg "Download completed in ${download_duration}s"
        info_msg "File size: $(du -h idle-finance.deb | cut -f1)"
        info_msg "Installing .deb package..."
        info_msg "Running: sudo dpkg -i idle-finance.deb"
        info_msg "Installation started at: $(date '+%H:%M:%S')"
        
        # Show loading indicator for installation
        sleek_loading "🔧 Installing .deb package" 3
        
        if $SUDO dpkg -i idle-finance.deb 2>/dev/null || $SUDO apt-get install -f -y && $SUDO dpkg -i idle-finance.deb; then
            local end_time=$(date +%s)
            local total_duration=$((end_time - start_time))
            success_msg "Idle Finance app installed successfully via .deb package"
            info_msg "Installed via system package manager"
            info_msg "Available as: idle-finance command"
            info_msg "Total time: ${total_duration}s (Download: ${download_duration}s, Install: $((total_duration - download_duration))s)"
            
            # Show colorful Idle Finance banner
            echo
            if command -v figlet >/dev/null 2>&1; then
                if [ -n "$COLOR_TOOL" ] && command -v "$COLOR_TOOL" >/dev/null 2>&1; then
                    case "$COLOR_TOOL" in
                        "rainbow")
                            figlet -f slant "IDLE FINANCE" | rainbow
                            ;;
                        "ccat")
                            figlet -f slant "IDLE FINANCE" | ccat
                            ;;
                        "bat")
                            figlet -f slant "IDLE FINANCE" | bat --style=plain --language=text
                            ;;
                        "highlight")
                            figlet -f slant "IDLE FINANCE" | highlight --out-format=ansi
                            ;;
                        "grc")
                            figlet -f slant "IDLE FINANCE" | grc -es --colour=auto
                            ;;
                    esac
                else
                    figlet -f slant "IDLE FINANCE"
                fi
            else
                echo "=== IDLE FINANCE ==="
            fi
            echo
            
            return 0
        else
            local end_time=$(date +%s)
            local total_duration=$((end_time - start_time))
            error_msg "Failed to install .deb package after ${total_duration}s"
            info_msg "This might be due to missing dependencies"
            return 1
        fi
    else
        local end_time=$(date +%s)
        local total_duration=$((end_time - start_time))
        error_msg "Could not download .deb package after ${total_duration}s"
        info_msg "Check your internet connection and try again"
        return 1
    fi
}

install_idle_finance_appimage() {
    info_msg "Downloading AppImage..."
    local appimage_url="https://github.com/holtdev/idle-finance/releases/download/v2.1/Idle.Finance-2.1.1-fixed.AppImage"
    local start_time=$(date +%s)
    
    info_msg "Download URL: $appimage_url"
    info_msg "Downloading AppImage..."
    info_msg "Started at: $(date '+%H:%M:%S')"
    
    # Show loading indicator for download
    sleek_loading "📥 Downloading AppImage" 3
    
    # Download with progress
    if curl -fsSL --progress-bar "$appimage_url" -o idle-finance.AppImage; then
        local download_time=$(date +%s)
        local download_duration=$((download_time - start_time))
        success_msg "Download completed in ${download_duration}s"
        info_msg "File size: $(du -h idle-finance.AppImage | cut -f1)"
        info_msg "Setting up AppImage..."
        info_msg "Making AppImage executable..."
        info_msg "Setup started at: $(date '+%H:%M:%S')"
        
        # Show loading indicator for setup
        sleek_loading "🔧 Setting up AppImage" 3
        
        chmod +x idle-finance.AppImage
        
        # Install to /usr/local/bin
        info_msg "Installing to /usr/local/bin/idle-finance..."
        
        # Show loading indicator for installation
        sleek_loading "📦 Installing to system" 3
        
        $SUDO mv idle-finance.AppImage /usr/local/bin/idle-finance
        success_msg "Idle Finance AppImage installed to /usr/local/bin/idle-finance"
        
        # Create desktop shortcut
        info_msg "Creating desktop shortcut..."
        info_msg "Creating /usr/share/applications/idle-finance.desktop..."
        
        # Show loading indicator for desktop shortcut
        sleek_loading "🖥️  Creating desktop shortcut" 3
        
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
        
        local end_time=$(date +%s)
        local total_duration=$((end_time - start_time))
        local setup_duration=$((total_duration - download_duration))
        success_msg "Desktop shortcut created"
        info_msg "Available as: idle-finance command"
        info_msg "Desktop shortcut: Applications > Idle Finance"
        info_msg "Total time: ${total_duration}s (Download: ${download_duration}s, Setup: ${setup_duration}s)"
        
        # Show colorful Idle Finance banner
        echo
        if command -v figlet >/dev/null 2>&1; then
            if [ -n "$COLOR_TOOL" ] && command -v "$COLOR_TOOL" >/dev/null 2>&1; then
                case "$COLOR_TOOL" in
                    "rainbow")
                        figlet -f slant "IDLE FINANCE" | rainbow
                        ;;
                    "ccat")
                        figlet -f slant "IDLE FINANCE" | ccat
                        ;;
                    "bat")
                        figlet -f slant "IDLE FINANCE" | bat --style=plain --language=text
                        ;;
                    "highlight")
                        figlet -f slant "IDLE FINANCE" | highlight --out-format=ansi
                        ;;
                    "grc")
                        figlet -f slant "IDLE FINANCE" | grc -es --colour=auto
                        ;;
                esac
            else
                figlet -f slant "IDLE FINANCE"
            fi
        else
            echo "=== IDLE FINANCE ==="
        fi
        echo
        
        return 0
    else
        local end_time=$(date +%s)
        local total_duration=$((end_time - start_time))
        error_msg "Failed to download Idle Finance AppImage after ${total_duration}s"
        info_msg "Check your internet connection and try again"
        return 1
    fi
}

install_idle_finance_app() {
    modern_step 6 7 "Installing Idle Finance Desktop App" "Setting up user interface..."
    
    info_msg "Installing Idle Finance Desktop App"
    
    # Always ask if user wants to install, regardless of current status
    if ! confirm "Install Idle Finance Desktop App (v${IDLE_FINANCE_VERSION})?"; then
        info_msg "Skipping Idle Finance app installation"
        return
    fi
    
    # Ask user for preference if not set
    local prefer_appimage="${PREFER_APPIMAGE}"
    if [ -z "$prefer_appimage" ]; then
        echo
        echo "${INFO}Choose installation method:${RESET}"
        echo "${CYAN}1)${RESET} .deb package (recommended for Ubuntu/Debian - better integration)"
        echo "${CYAN}2)${RESET} AppImage (portable, works on any Linux)"
        echo
        while true; do
            printf "${WARNING}Enter choice (1 or 2):${RESET} "
            read -r choice
            case $choice in
                1) prefer_appimage="0"; break ;;
                2) prefer_appimage="1"; break ;;
                *) echo "${ERROR}Please enter 1 or 2${RESET}";;
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
            warning_msg "Falling back to AppImage installation..."
            install_idle_finance_appimage
        fi
    fi
    
    cd - > /dev/null
    rm -rf "$temp_dir"
}

# =============================================================================
# ✅ VERIFICATION & SUMMARY
# =============================================================================

verify_summary() {
    modern_step 7 7 "Verifying Installation" "Final system check..."
    
    info_msg "Verification summary"
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
    
    info_msg "Done. If you were added to group 'kvm', you may need to log out/in."
}

# =============================================================================
# 🎯 MAIN EXECUTION
# =============================================================================

main() {
    start_timer "total_bootstrap"
    
    # Initialize COLOR_TOOL variable
    COLOR_TOOL=""
    
    # Check for existing color tools before banner
    if command -v rainbow >/dev/null 2>&1; then
        COLOR_TOOL="rainbow"
    elif command -v ccat >/dev/null 2>&1; then
        COLOR_TOOL="ccat"
    elif command -v bat >/dev/null 2>&1; then
        COLOR_TOOL="bat"
    elif command -v highlight >/dev/null 2>&1; then
        COLOR_TOOL="highlight"
    elif command -v grc >/dev/null 2>&1; then
        COLOR_TOOL="grc"
    fi
    
    # Show sleek startup banner
    show_startup_banner
    
    info_msg "This script will check and install all requirements for running Golem provider"
    info_msg "Set AUTO_CONFIRM=1 to skip confirmation prompts"
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
    
    # Install Idle Finance app if requested
    if [ "${INSTALL_IDLE_FINANCE}" = "1" ]; then
        install_idle_finance_app
    fi
    
    end_timer "total_bootstrap"
    
    # Show sleek success banner
    show_success_banner
    
    echo
    success_msg "🚀 Your Idle Finance Golem provider is ready to earn rewards!"
    echo
    
    # Show app installation status and access information
    if command -v idle-finance >/dev/null 2>&1 || [ -f "/opt/Idle-Finance/idle-finance" ] || [ -f "/usr/local/bin/idle-finance" ]; then
        sleek_card "🎉 IDLE FINANCE DESKTOP APP INSTALLED SUCCESSFULLY! 🎉" "Your desktop app is ready to use!" "$GRADIENT_GREEN"
        sleek_card "🚀 HOW TO ACCESS YOUR IDLE FINANCE APP" "💻 Terminal Command: idle-finance\n🖥️  Desktop Menu: Applications > Idle Finance\n🔍 App Search: Search for 'Idle Finance' in your app menu\n\n💡 PRO TIP: The app will help you manage your Golem provider!" "$GRADIENT_BLUE"
    else
        sleek_banner "📱 IDLE FINANCE DESKTOP APP NOT INSTALLED 📱" "$GRADIENT_PURPLE"
        sleek_banner "🔧 DOWNLOAD & INSTALL THE DESKTOP APP" "$GRADIENT_ORANGE"
        sleek_banner "The desktop app is highly recommended!" "$GRADIENT_ORANGE"
        printf "\n"
        printf "\n"
        info_msg "To install the desktop app later for Ubuntu/Debian, run the following commands:"
        info_msg "wget https://github.com/holtdev/idle-finance/releases/download/v2.1/idle-finance_2.1.1_amd64.deb"
        info_msg "sudo dpkg -i idle-finance_2.1.1_amd64.deb"
        printf "\n"
        printf "\n"
        info_msg "To install the desktop app later for other Linux distributions, run the following commands:"
        info_msg "wget https://github.com/holtdev/idle-finance/releases/download/v2.1/Idle.Finance-2.1.1-fixed.AppImage"
        info_msg "chmod +x Idle.Finance-2.1.1-fixed.AppImage"
        info_msg "sudo mv Idle.Finance-2.1.1-fixed.AppImage /usr/local/bin/idle-finance"
        info_msg "sudo chmod +x /usr/local/bin/idle-finance"
    fi
}

main "$@"
