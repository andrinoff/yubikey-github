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
# Color codes for output
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

# 2. Check for Dependencies
check_dependencies() {
    info "Checking for required dependencies..."
    
    # Check for GnuPG
    if ! command -v gpg &> /dev/null; then
        warn "GnuPG (gpg) is not installed."
        install_dependencies
    else
        success "GnuPG is installed."
    fi

    # Check for Git
    if ! command -v git &> /dev/null; then
        fail "Git is not installed. Please install Git and re-run the script."
    else
        success "Git is installed."
    fi
}

# 3. Install Dependencies
install_dependencies() {
    info "Attempting to install missing dependencies..."
    case $OS in
        'macOS')
            if ! command -v brew &> /dev/null; then
                fail "Homebrew is not installed. Please install Homebrew (https://brew.sh) and re-run the script."
            fi
            info "Installing GnuPG, pinentry-mac, and yubikey-personalization via Homebrew..."
            brew install gnupg pinentry-mac yubikey-personalization
            echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
            success "Dependencies installed."
            ;;
        'Linux')
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
            ;;
    esac
    # Reload gpg-agent
    gpg-connect-agent reloadagent /bye &>/dev/null || true
}

# 4. YubiKey GPG Setup
setup_yubikey_gpg() {
    info "Starting YubiKey GPG setup..."
    
    # Check for YubiKey
    if ! gpg --card-status &> /dev/null; then
        fail "No YubiKey detected. Please insert your YubiKey and ensure GPG can access it."
    fi
    success "YubiKey detected."

    # Generate GPG key on YubiKey
    info "This script will now generate a new GPG key on your YubiKey."
    warn "This will overwrite any existing GPG key on the device."
    read -p "Do you want to continue? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        fail "GPG setup aborted."
    fi

    # Get user details
    read -p "Enter your full name: " name
    read -p "Enter your email address: " email

    # Generate key
    gpg --batch --passphrase '' --quick-generate-key "$name <$email>" default default
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG "$email" | grep sec | awk '{print $2}' | cut -d'/' -f2)
    success "GPG key generated with ID: $GPG_KEY_ID"

    # Move key to YubiKey
    info "Moving the generated key to your YubiKey..."
    gpg --edit-key "$GPG_KEY_ID" <<EOF
keytocard
y
1
y
2
y
3
y
save
EOF
    success "GPG key moved to YubiKey."
    
    # Set touch policy
    info "Setting touch policy for signatures..."
    gpg --card-edit <<EOF
admin
key 1
y
key 2
n
key 3
n
quit
EOF
    success "Touch policy set."
}

# 5. Configure Git
configure_git() {
    info "Configuring Git for GPG signing..."
    git config --global user.signingkey "$GPG_KEY_ID"
    git config --global commit.gpgsign true
    if [[ "$OS" == "macOS" || "$OS" == "Linux" ]]; then
        git config --global gpg.program "$(which gpg)"
    fi
    success "Git configured to use GPG key $GPG_KEY_ID for signing."
}

# 6. Export GPG Key for GitHub
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
    check_dependencies
    setup_yubikey_gpg
    configure_git
    export_gpg_key
    
    success "YubiKey GPG setup complete!"
}

main
