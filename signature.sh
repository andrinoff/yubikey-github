#!/usr/bin/env bash

# YubiKey GPG/SSH Setup Script
#
# This script automates the process of setting up a YubiKey for GPG commit
# signing and SSH authentication with GitHub.
#
# Supported OS: macOS, Linux (Debian/Ubuntu/Fedora), Windows (via WSL)

# --- Configuration ---
set -eo pipefail # Exit on error

# --- Helper Functions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# --- Main Functions ---

# 1. Detect Operating System
detect_os() {
    info "Detecting operating system..."
    case "$(uname -s)" in
        Linux*)     OS='Linux';;
        Darwin*)    OS='macOS';;
        *)          fail "Unsupported operating system. This script runs on macOS, Linux, and Windows (via WSL).";;
    esac
    success "Detected OS: $OS"
}

# 2. Install Dependencies
install_dependencies() {
    info "Checking and installing dependencies..."
    case $OS in
        'macOS')
            if ! command -v brew &> /dev/null; then
                fail "Homebrew is not installed. Please install Homebrew (https://brew.sh) and re-run the script."
            fi
            info "Installing GnuPG, pinentry-mac, and yubikey-personalization via Homebrew..."
            brew install gnupg pinentry-mac yubikey-personalization
            
            # FIX: Ensure .gnupg directory exists before writing to it
            info "Configuring gpg-agent..."
            mkdir -p ~/.gnupg
            echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" > ~/.gnupg/gpg-agent.conf
            
            success "Dependencies installed and configured."
            ;;
        'Linux')
            if ! command -v gpg &> /dev/null; then
                 if [ -f /etc/debian_version ]; then
                    info "Installing dependencies for Debian/Ubuntu..."
                    sudo apt-get update && sudo apt-get install -y gnupg2 pcscd scdaemon
                elif [ -f /etc/fedora-release ]; then
                    info "Installing dependencies for Fedora..."
                    sudo dnf install -y gnupg2 pcscd
                else
                    fail "Unsupported Linux distribution. Please install GnuPG manually."
                fi
                success "Dependencies installed."
            fi
            ;;
    esac
    # Reload gpg-agent to apply changes
    gpg-connect-agent reloadagent /bye &>/dev/null || true
}

# 3. YubiKey GPG Setup
setup_yubikey_gpg() {
    info "Starting YubiKey GPG setup..."
    
    if ! gpg --card-status &> /dev/null; then
        fail "No YubiKey detected. Please insert your YubiKey and ensure GPG can access it."
    fi
    success "YubiKey detected."

    warn "This script will generate a new GPG key on your YubiKey, overwriting any existing one."
    read -p "Do you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
        fail "GPG setup aborted."
    fi

    read -p "Enter your full name: " name
    read -p "Enter your email address (must match your GitHub email): " email

    # Use gpg's --generate-key in batch mode for simplicity
    info "Generating GPG key. You will be prompted for your YubiKey Admin PIN and to touch the device."
    gpg --expert --full-generate-key
    
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG "$email" | grep sec | awk '{print $2}' | cut -d'/' -f2)
    if [ -z "$GPG_KEY_ID" ]; then
        fail "Could not determine GPG Key ID. Please ensure the email matches."
    fi
    success "GPG key generated with ID: $GPG_KEY_ID"

    info "Moving key stubs to the YubiKey..."
    gpg --edit-key "$GPG_KEY_ID" <<EOF
keytocard
1
2
3
save
EOF
    success "GPG key moved to YubiKey."
}

# 4. Configure Git
configure_git() {
    info "Configuring Git for GPG signing..."
    git config --global user.signingkey "$GPG_KEY_ID"
    git config --global commit.gpgsign true
    if [[ "$OS" == "macOS" || "$OS" == "Linux" ]]; then
        git config --global gpg.program "$(which gpg)"
    fi
    success "Git configured to use GPG key $GPG_KEY_ID for signing."
}

# 5. Export GPG Key for GitHub
export_gpg_key() {
    info "Exporting GPG public key for GitHub..."
    GPG_PUBLIC_KEY=$(gpg --armor --export "$GPG_KEY_ID")
    
    echo -e "\n--- Your GPG Public Key ---"
    echo -e "${YELLOW}$GPG_PUBLIC_KEY${NC}"
    echo "--------------------------"
    success "Copy the key above and add it to your GitHub account:"
    echo "https://github.com/settings/gpg_keys"
}


# --- Main Execution ---
main() {
    detect_os
    install_dependencies
    setup_yubikey_gpg
    configure_git
    export_gpg_key
    
    success "YubiKey GPG setup complete!"
}

main

