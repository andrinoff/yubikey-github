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

# 2. Check Dependencies
check_dependencies() {
    info "Checking for required dependencies..."
    if ! command -v ssh-keygen &> /dev/null; then
        fail "OpenSSH client (ssh-keygen) not found. Please install it and re-run."
    else
        success "OpenSSH client is installed."
    fi

    # Check for YubiKey Manager CLI (ykman) to guide PIN setup
    if ! command -v ykman &> /dev/null; then
        warn "YubiKey Manager (ykman) not found. Will provide manual instructions for PIN."
        YKMAN_INSTALLED=false
    else
        success "YubiKey Manager (ykman) is installed."
        YKMAN_INSTALLED=true
    fi
}

# 3. Verify FIDO2 PIN
verify_pin() {
    info "Your YubiKey needs a FIDO2 PIN to create a security key."
    warn "If you have not set a PIN yet, you must do so now."
    if [ "$YKMAN_INSTALLED" = true ]; then
        info "You can set one now by running: ${YELLOW}ykman fido access change-pin${NC}"
    else
        info "Please use the YubiKey Manager GUI to set a FIDO2 PIN under Applications > FIDO2."
    fi
    read -p "Have you set a FIDO2 PIN on your YubiKey? (y/N): " confirm
    if [[ "$confirm" != "y" ]]; then
        fail "PIN setup aborted. Please set a PIN and re-run the script."
    fi
}

# 4. Generate SSH Key
generate_ssh_key() {
    info "Generating a new hardware-backed SSH key..."
    
    # Define key path
    KEY_PATH="$HOME/.ssh/id_ed25519_sk_github"
    if [ -f "$KEY_PATH" ]; then
        warn "Key file already exists at $KEY_PATH."
        read -p "Do you want to overwrite it? (y/N): " overwrite_confirm
        if [[ "$overwrite_confirm" != "y" ]]; then
            fail "Key generation aborted."
        fi
        rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
    fi

    info "When prompted, you will need to touch your flashing YubiKey."
    # Generate the key. -O resident makes the key portable.
    ssh-keygen -t ed25519-sk -f "$KEY_PATH" -O resident -O application=ssh:github -O verify-required -C "github-$(whoami)@$(hostname)"
    
    success "SSH key generated successfully at ${KEY_PATH}"
}

# 5. Configure SSH Agent
configure_ssh_agent() {
    info "Configuring the SSH agent..."
    # Ensure ssh-agent is running
    eval "$(ssh-agent -s)" > /dev/null

    # Add key to agent
    if [[ "$OS" == "macOS" ]]; then
        # Store passphrase in macOS Keychain
        ssh-add --apple-use-keychain "$KEY_PATH"
    else
        ssh-add "$KEY_PATH"
    fi
    success "Key added to the SSH agent."

    # Configure ~/.ssh/config
    CONFIG_PATH="$HOME/.ssh/config"
    info "Updating SSH config at ${CONFIG_PATH}..."
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
    check_dependencies
    verify_pin
    generate_ssh_key
    configure_ssh_agent
    display_public_key

    # Final test
    read -p "Do you want to test the connection to GitHub now? (y/N): " test_conn
    if [[ "$test_conn" == "y" ]]; then
        info "Attempting to authenticate. Touch your YubiKey when it flashes."
        ssh -T git@github.com
    fi
    
    success "YubiKey SSH setup complete!"
}

main
