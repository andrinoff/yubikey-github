#!/usr/bin/env bash

# YubiKey SSH Auto-Setup Script for GitHub
#
# This script automates setting up a YubiKey for SSH authentication with GitHub.
# It generates a hardware-backed SSH key and configures the SSH agent.
#
# Supported OS: macOS, Linux (Debian/Ubuntu/Fedora)

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
        *)          fail "Unsupported OS. This script is for macOS and Linux.";;
    esac
    success "Detected OS: $OS"
}

# 2. Install Dependencies
install_dependencies() {
    info "Checking and installing dependencies..."
    case $OS in
        'macOS')
            if ! command -v brew &> /dev/null; then
                fail "Homebrew is not installed. Please install Homebrew (https://brew.sh) and re-run."
            fi
            info "Installing openssh and ykman via Homebrew..."
            brew install openssh ykman
            success "Dependencies installed."
            ;;
        'Linux')
            if ! command -v ssh-keygen &> /dev/null; then
                if [ -f /etc/debian_version ]; then
                    sudo apt-get update && sudo apt-get install -y openssh-client
                elif [ -f /etc/fedora-release ]; then
                    sudo dnf install -y openssh-clients
                else
                    fail "OpenSSH client not found. Please install it manually."
                fi
            fi
            ;;
    esac
}

# 3. Verify FIDO2 PIN
verify_pin() {
    info "Your YubiKey needs a FIDO2 PIN to create a security key."
    warn "If you have not set a PIN yet, you must do so now."
    info "You can set one by running: ${YELLOW}ykman fido access change-pin${NC}"
    read -p "Have you set a FIDO2 PIN on your YubiKey? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
        fail "PIN setup aborted. Please set a PIN and re-run the script."
    fi
}

# 4. Generate SSH Key
generate_ssh_key() {
    info "Generating a new hardware-backed SSH key..."
    
    KEY_PATH="$HOME/.ssh/id_ed25519_sk_github"
    if [ -f "$KEY_PATH" ]; then
        warn "Key file already exists at $KEY_PATH."
        read -p "Do you want to overwrite it? (y/N): " overwrite_confirm
        if [[ ! "$overwrite_confirm" =~ ^[yY](es)?$ ]]; then
            fail "Key generation aborted."
        fi
        rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
    fi

    info "When prompted, you will need to touch your flashing YubiKey."
    ssh-keygen -t ed25519-sk -f "$KEY_PATH" -O resident -O application=ssh:github -O verify-required -C "github-$(whoami)@$(hostname)"
    
    success "SSH key generated successfully at ${KEY_PATH}"
}

# 5. Configure SSH Agent
configure_ssh_agent() {
    info "Configuring the SSH agent..."

    # Add key to agent
    if [[ "$OS" == "macOS" ]]; then
        # FIX: Explicitly use the Homebrew-installed ssh-agent and ssh-add to avoid path issues.
        local brew_prefix
        brew_prefix=$(brew --prefix)
        info "Using Homebrew OpenSSH binaries from $brew_prefix"
        
        eval "$(${brew_prefix}/bin/ssh-agent -s)" > /dev/null
        ssh-add "$KEY_PATH"
    else
        eval "$(ssh-agent -s)" > /dev/null
        ssh-add "$KEY_PATH"
    fi
    success "Key added to the SSH agent."

    CONFIG_PATH="$HOME/.ssh/config"
    info "Updating SSH config at ${CONFIG_PATH}..."
    mkdir -p "$(dirname "$CONFIG_PATH")"
    {
        echo ""
        echo "# YubiKey SSH configuration for GitHub (added by script)"
        echo "Host github.com"
        echo "  IdentityFile ${KEY_PATH}"
        echo "  IdentitiesOnly yes"
    } >> "$CONFIG_PATH"
    success "SSH config updated to use the new key for github.com."
}

# 6. Display Public Key for GitHub
display_public_key() {
    info "Your new SSH public key is:"
    echo -e "${YELLOW}"
    cat "${KEY_PATH}.pub"
    echo -e "${NC}"
    success "Copy the entire public key above and add it to your GitHub account:"
    info "https://github.com/settings/ssh/new"
}

# --- Main Execution ---
main() {
    detect_os
    install_dependencies
    verify_pin
    generate_ssh_key
    configure_ssh_agent
    display_public_key

    read -p "Do you want to test the connection to GitHub now? (y/N): " test_conn
    if [[ "$test_conn" =~ ^[yY](es)?$ ]]; then
        info "Attempting to authenticate. Touch your YubiKey when it flashes."
        ssh -T git@github.com
    fi
    
    success "YubiKey SSH setup complete!"
}

main

