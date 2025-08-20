#!/usr/bin/env bash
set -euo pipefail

# Configuration
: "${NONINTERACTIVE:=1}"
: "${AUTO_CONFIRM:=1}"

# Utility functions
confirm() {
    echo "Auto-confirming: $1"
    return 0
}

need_sudo() {
    SUDO=sudo
}

# Uninstall Golem provider
uninstall_golem() {
    echo "STEP 1/4: Uninstalling Golem Provider"
    
    if command -v golemsp >/dev/null 2>&1; then
        echo "INFO: Stopping Golem provider if running..."
        pkill -f golemsp || true
        
        echo "INFO: Removing Golem provider..."
        # Try to find and remove Golem installation
        if [ -d "$HOME/.golem" ]; then
            echo "INFO: Removing Golem configuration directory..."
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
                echo "INFO: Removing Golem binary: $path"
                rm -f "$path"
            fi
        done
        
        echo "SUCCESS: Golem provider uninstalled"
    else
        echo "INFO: Golem provider not found, skipping"
    fi
}

# Uninstall automation service
uninstall_automation_service() {
    echo "STEP 2/4: Uninstalling Automation Service"
    
    echo "INFO: Stopping automation service..."
    $SUDO systemctl stop idle-finance-automation.service 2>/dev/null || true
    $SUDO systemctl disable idle-finance-automation.service 2>/dev/null || true
    
    echo "INFO: Removing automation service files..."
    $SUDO rm -f /etc/systemd/system/idle-finance-automation.service
    $SUDO rm -rf /opt/idle-finance-automation
    $SUDO rm -rf /var/log/idle-finance-automation
    
    echo "INFO: Reloading systemd..."
    $SUDO systemctl daemon-reload
    
    echo "SUCCESS: Automation service uninstalled"
}

# Remove KVM setup
uninstall_kvm() {
    echo "STEP 3/4: Removing KVM Setup"
    
    echo "INFO: Removing user from kvm group..."
    $SUDO gpasswd -d "$USER" kvm 2>/dev/null || true
    
    echo "INFO: Removing KVM modules from boot..."
    $SUDO sed -i '/^kvm$/d' /etc/modules 2>/dev/null || true
    $SUDO sed -i '/^kvm_intel$/d' /etc/modules 2>/dev/null || true
    $SUDO sed -i '/^kvm_amd$/d' /etc/modules 2>/dev/null || true
    
    echo "INFO: Removing udev rule..."
    $SUDO rm -f /etc/udev/rules.d/60-kvm.rules
    
    echo "INFO: Unloading KVM modules..."
    $SUDO modprobe -r kvm_intel 2>/dev/null || true
    $SUDO modprobe -r kvm_amd 2>/dev/null || true
    $SUDO modprobe -r kvm 2>/dev/null || true
    
    echo "SUCCESS: KVM setup removed"
}

# Remove system packages
uninstall_packages() {
    echo "STEP 4/4: Removing System Packages"
    
    echo "INFO: Removing KVM and virtualization packages..."
    $SUDO apt-get remove -y --purge qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils cpu-checker 2>/dev/null || true
    
    echo "INFO: Removing Python packages..."
    $SUDO apt-get remove -y --purge python3-venv python3-pip 2>/dev/null || true
    
    echo "INFO: Removing other dependencies..."
    $SUDO apt-get remove -y --purge expect figlet 2>/dev/null || true
    
    echo "INFO: Cleaning up unused packages..."
    $SUDO apt-get autoremove -y
    $SUDO apt-get autoclean
    
    echo "SUCCESS: System packages removed"
}

# Uninstall idle-finance app
uninstall_idle_finance() {
    echo "STEP 5/5: Uninstalling idle-finance App"
    
    echo "INFO: Removing idle-finance package if installed via apt..."
    if dpkg -l | grep -q idle-finance; then
        $SUDO apt purge -y idle-finance
        $SUDO apt autoremove -y
        echo "SUCCESS: idle-finance package removed"
    else
        echo "INFO: idle-finance package not found in apt, skipping..."
    fi
    
    echo "INFO: Removing user configs and cache..."
    rm -rf ~/.config/idle-finance
    rm -rf ~/.local/share/idle-finance
    rm -rf ~/.cache/idle-finance
    
    echo "INFO: Removing possible system-wide folders..."
    $SUDO rm -rf /etc/idle-finance
    $SUDO rm -rf /usr/share/idle-finance
    
    echo "SUCCESS: idle-finance app and configs fully removed"
}

# Clean up PATH modifications
cleanup_path() {
    echo "INFO: Cleaning up PATH modifications..."
    
    if grep -q "\.local/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo "INFO: Removing ~/.local/bin from PATH in ~/.bashrc"
        sed -i '/export PATH="$HOME\/.local\/bin:$PATH"/d' "$HOME/.bashrc"
    fi
    
    echo "SUCCESS: PATH cleanup completed"
}

# Verification
verify_uninstall() {
    echo "UNINSTALL VERIFICATION:"
    
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
    echo "GOLEM CORE UNINSTALLER"
    echo "======================"
    echo ""
    echo "This script will remove Golem provider, automation services, KVM setup, and dependencies"
    echo "Running in auto-confirm mode - no user interaction required"
    echo ""
    
    need_sudo
    
    uninstall_golem
    uninstall_automation_service
    uninstall_kvm
    uninstall_packages
    cleanup_path
    
    verify_uninstall
    
    echo ""
    echo "GOLEM CORE UNINSTALL COMPLETED!"
    echo "==============================="
    echo ""
    echo "All Golem-related components have been removed from your system."
    echo ""
    echo "NOTE: You may need to log out and back in for all changes to take effect."
    echo "NOTE: Some packages may still be present if they are dependencies for other software."
}

main "$@"




