#!/usr/bin/env bash
set -euo pipefail

# Configuration
: "${NONINTERACTIVE:=1}"
: "${AUTO_CONFIRM:=1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Utility functions
confirm() {
    echo "Auto-confirming: $1"
    return 0
}

need_sudo() {
    SUDO=sudo
}

# Uninstall Idle Finance app
uninstall_idle_finance_app() {
    echo "STEP 1/5: Uninstalling Idle Finance App"
    
    log_info "Stopping Idle Finance processes..."
    pkill -f "idle-finance" || true
    pkill -f "electron" || true
    pkill -f "node.*idle" || true
    
    log_info "Removing Idle Finance application directories..."
    
    # Remove application directories
    local app_dirs=(
        "$HOME/.config/idle-finance"
        "$HOME/.local/share/idle-finance"
        "$HOME/.cache/idle-finance"
        "$HOME/Desktop/idle-finance.desktop"
        "$HOME/.local/share/applications/idle-finance.desktop"
        "/usr/share/applications/idle-finance.desktop"
        "/opt/idle-finance"
        "/usr/local/bin/idle-finance"
        "$HOME/.local/bin/idle-finance"
    )
    
    for dir in "${app_dirs[@]}"; do
        if [ -e "$dir" ]; then
            log_info "Removing: $dir"
            $SUDO rm -rf "$dir"
        fi
    done
    
    # Remove from current workspace if it's the Idle Finance project
    if [[ "$PWD" == *"idle-finance"* ]]; then
        log_warning "Current directory appears to be the Idle Finance project"
        log_info "You may want to manually remove the project directory: $PWD"
    fi
    
    log_success "Idle Finance app uninstalled"
}

# Uninstall Golem provider
uninstall_golem() {
    echo "STEP 2/5: Uninstalling Golem Provider"
    
    if command -v golemsp >/dev/null 2>&1; then
        log_info "Stopping Golem provider if running..."
        pkill -f golemsp || true
        
        log_info "Removing Golem provider..."
        # Try to find and remove Golem installation
        if [ -d "$HOME/.golem" ]; then
            log_info "Removing Golem configuration directory..."
            rm -rf "$HOME/.golem"
        fi
        
        # Try to remove from common installation locations
        local golem_paths=(
            "$HOME/.local/bin/golemsp"
            "/usr/local/bin/golemsp"
            "/usr/bin/golemsp"
            "$HOME/.cargo/bin/golemsp"
        )
        
        for path in "${golem_paths[@]}"; do
            if [ -f "$path" ]; then
                log_info "Removing Golem binary: $path"
                rm -f "$path"
            fi
        done
        
        log_success "Golem provider uninstalled"
    else
        log_info "Golem provider not found, skipping"
    fi
}

# Uninstall automation service
uninstall_automation_service() {
    echo "STEP 3/5: Uninstalling Automation Service"
    
    log_info "Stopping and disabling automation service..."
    $SUDO systemctl stop idle-finance-automation.service 2>/dev/null || true
    $SUDO systemctl disable idle-finance-automation.service 2>/dev/null || true
    
    log_info "Stopping and disabling backend service..."
    $SUDO systemctl stop idle-finance-backend.service 2>/dev/null || true
    $SUDO systemctl disable idle-finance-backend.service 2>/dev/null || true
    
    log_info "Removing automation binary and service files..."
    # Remove automation binary directory (user-specific path)
    if [ -d "$HOME/idle-finance-automation" ]; then
        log_info "Removing automation binary directory: $HOME/idle-finance-automation"
        $SUDO rm -rf "$HOME/idle-finance-automation"
    fi
    
    # Remove system service files
    $SUDO rm -f /etc/systemd/system/idle-finance-automation.service
    $SUDO rm -f /etc/systemd/system/idle-finance-backend.service
    
    # Remove installation directories
    $SUDO rm -rf /opt/idle-finance-automation
    $SUDO rm -rf /opt/idle-finance-backend
    
    # Remove log directories
    $SUDO rm -rf /var/log/idle-finance-automation
    $SUDO rm -rf /var/log/idle-finance-backend
    
    # Remove user-specific log files
    if [ -d "$HOME/.local/share/idle-finance-automation" ]; then
        log_info "Removing user automation logs: $HOME/.local/share/idle-finance-automation"
        rm -rf "$HOME/.local/share/idle-finance-automation"
    fi
    
    log_info "Removing any remaining service files..."
    $SUDO rm -f /etc/systemd/system/idle-finance-*.service
    
    log_info "Reloading systemd..."
    $SUDO systemctl daemon-reload
    $SUDO systemctl reset-failed 2>/dev/null || true
    
    log_success "Automation and backend services uninstalled"
}

# Remove KVM setup
uninstall_kvm() {
    echo "STEP 4/5: Removing KVM Setup"
    
    log_info "Removing user from kvm group..."
    $SUDO gpasswd -d "$USER" kvm 2>/dev/null || true
    
    log_info "Removing KVM modules from boot..."
    $SUDO sed -i '/^kvm$/d' /etc/modules 2>/dev/null || true
    $SUDO sed -i '/^kvm_intel$/d' /etc/modules 2>/dev/null || true
    $SUDO sed -i '/^kvm_amd$/d' /etc/modules 2>/dev/null || true
    
    log_info "Removing udev rule..."
    $SUDO rm -f /etc/udev/rules.d/60-kvm.rules
    
    log_info "Unloading KVM modules..."
    $SUDO modprobe -r kvm_intel 2>/dev/null || true
    $SUDO modprobe -r kvm_amd 2>/dev/null || true
    $SUDO modprobe -r kvm 2>/dev/null || true
    
    log_success "KVM setup removed"
}

# Remove system packages
uninstall_packages() {
    echo "STEP 5/5: Removing System Packages"
    
    log_info "Removing KVM and virtualization packages..."
    $SUDO apt-get remove -y --purge qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker 2>/dev/null || true
    
    log_info "Removing Python packages..."
    $SUDO apt-get remove -y --purge python3-venv python3-pip 2>/dev/null || true
    
    log_info "Removing other dependencies..."
    $SUDO apt-get remove -y --purge expect figlet 2>/dev/null || true
    
    log_info "Cleaning up unused packages..."
    $SUDO apt-get autoremove -y
    $SUDO apt-get autoclean
    
    log_success "System packages removed"
}

# Clean up PATH modifications
cleanup_path() {
    log_info "Cleaning up PATH modifications..."
    
    if grep -q "\.local/bin" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Removing ~/.local/bin from PATH in ~/.bashrc"
        sed -i '/export PATH="$HOME\/.local\/bin:$PATH"/d' "$HOME/.bashrc"
    fi
    
    # Remove any Idle Finance related PATH entries
    if grep -q "idle-finance" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Removing Idle Finance PATH entries from ~/.bashrc"
        sed -i '/idle-finance/d' "$HOME/.bashrc"
    fi
    
    log_success "PATH cleanup completed"
}

# Clean up additional configuration files
cleanup_configs() {
    log_info "Cleaning up additional configuration files..."
    
    # Remove any remaining config files
    local config_files=(
        "$HOME/.config/idle-finance"
        "$HOME/.idle-finance"
        "$HOME/.golem"
        "$HOME/.local/share/idle-finance"
        "$HOME/.cache/idle-finance"
        "$HOME/.npm/_cacache"
        "$HOME/.yarn/cache"
    )
    
    for config in "${config_files[@]}"; do
        if [ -e "$config" ]; then
            log_info "Removing config: $config"
            rm -rf "$config"
        fi
    done
    
    # Clean up any environment variables
    if grep -q "IDLE_FINANCE" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Removing Idle Finance environment variables from ~/.bashrc"
        sed -i '/IDLE_FINANCE/d' "$HOME/.bashrc"
    fi
    
    if grep -q "GOLEM" "$HOME/.bashrc" 2>/dev/null; then
        log_info "Removing Golem environment variables from ~/.bashrc"
        sed -i '/GOLEM/d' "$HOME/.bashrc"
    fi
    
    log_success "Configuration cleanup completed"
}

# Verification
verify_uninstall() {
    echo "UNINSTALL VERIFICATION:"
    echo "======================"
    
    # Check Idle Finance app
    if [ -d "$HOME/.config/idle-finance" ]; then
        echo " - Idle Finance config: STILL PRESENT"
    else
        echo " - Idle Finance config: REMOVED"
    fi
    
    if pgrep -f "idle-finance" >/dev/null; then
        echo " - Idle Finance processes: STILL RUNNING"
    else
        echo " - Idle Finance processes: STOPPED"
    fi
    
    # Check Golem
    if command -v golemsp >/dev/null 2>&1; then
        echo " - golemsp: STILL PRESENT"
    else
        echo " - golemsp: REMOVED"
    fi

    if [ -d "$HOME/.golem" ]; then
        echo " - ~/.golem directory: STILL PRESENT"
    else
        echo " - ~/.golem directory: REMOVED"
    fi

    if $SUDO systemctl is-active --quiet idle-finance-automation.service 2>/dev/null; then
        echo " - automation service: STILL RUNNING"
    else
        echo " - automation service: STOPPED"
    fi

    if $SUDO systemctl is-active --quiet idle-finance-backend.service 2>/dev/null; then
        echo " - backend service: STILL RUNNING"
    else
        echo " - backend service: STOPPED"
    fi

    if [ -f /etc/systemd/system/idle-finance-automation.service ]; then
        echo " - automation service file: STILL PRESENT"
    else
        echo " - automation service file: REMOVED"
    fi

    if [ -f /etc/systemd/system/idle-finance-backend.service ]; then
        echo " - backend service file: STILL PRESENT"
    else
        echo " - backend service file: REMOVED"
    fi

    if [ -d "$HOME/idle-finance-automation" ]; then
        echo " - automation binary directory: STILL PRESENT"
    else
        echo " - automation binary directory: REMOVED"
    fi

    if [ -d "$HOME/.local/share/idle-finance-automation" ]; then
        echo " - user automation logs: STILL PRESENT"
    else
        echo " - user automation logs: REMOVED"
    fi

    if [ -e /dev/kvm ]; then
        echo " - /dev/kvm: STILL PRESENT"
    else
        echo " - /dev/kvm: REMOVED"
    fi

    if id -nG "$USER" | grep -qw kvm; then
        echo " - user in group 'kvm': STILL MEMBER"
    else
        echo " - user in group 'kvm': REMOVED"
    fi

    if dpkg -l | grep -q "qemu-kvm\|libvirt"; then
        echo " - KVM packages: STILL INSTALLED"
    else
        echo " - KVM packages: REMOVED"
    fi

    echo "Uninstall verification completed"
}

# Main execution
main() {
    echo "IDLE FINANCE & GOLEM CORE UNINSTALLER"
    echo "====================================="
    echo ""
    echo "This script will remove:"
    echo "- Idle Finance application and all config files"
    echo "- Golem provider and automation services"
    echo "- KVM setup and virtualization packages"
    echo "- All related dependencies and configurations"
    echo ""
    echo "Running in auto-confirm mode - no user interaction required"
    echo ""
    
    need_sudo
    
    uninstall_idle_finance_app
    uninstall_golem
    uninstall_automation_service
    uninstall_kvm
    uninstall_packages
    cleanup_path
    cleanup_configs
    
    verify_uninstall
    
    echo ""
    echo "IDLE FINANCE & GOLEM CORE UNINSTALL COMPLETED!"
    echo "=============================================="
    echo ""
    echo "All Idle Finance and Golem-related components have been removed from your system."
    echo ""
    echo "NOTE: You may need to log out and back in for all changes to take effect."
    echo "NOTE: Some packages may still be present if they are dependencies for other software."
    echo "NOTE: If you want to completely remove the project directory, please do so manually."
}

main "$@"




