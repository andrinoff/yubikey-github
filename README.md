# Enhance Your GitHub Security with YubiKey

![Windows](https://img.shields.io/badge/Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white)
![macOS](https://img.shields.io/badge/mac%20os-000000?style=for-the-badge&logo=apple&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

This repository contains two comprehensive tutorials designed to significantly improve the security of your GitHub workflow using a YubiKey hardware token. By following these guides, you can protect your account with hardware-backed authentication and ensure the integrity of your commits.

---

## Available Guides

### 1. SSH Authentication with YubiKey
![SSH](https://img.shields.io/badge/SSH-336791?style=for-the-badge&logo=server-fault&logoColor=white)

This guide walks you through setting up your YubiKey to handle SSH authentication for your GitHub account. Instead of using a password or a conventional SSH key file, you will use your YubiKey to physically approve push/pull operations.

-   **Features:** FIDO2/U2F keys, resident keys for portability, and OS-specific SSH agent configuration.
-   **Outcome:** Phishing-resistant, hardware-based authentication for all Git operations.

➡️ **[View the Full SSH Setup Guide](./ssh.md)**

---

### 2. GPG Commit Signing with YubiKey
![GPG](https://img.shields.io/badge/GnuPG-004D99?style=for-the-badge&logo=gnome&logoColor=white)

This guide explains how to configure your YubiKey to sign your Git commits using GPG. This process adds a "Verified" badge to your commits on GitHub, proving they came from you and have not been tampered with.

-   **Features:** On-device key generation, PIN protection, and signature-by-touch policy.
-   **Outcome:** Cryptographically verified commits that enhance the trust and integrity of your repository.

➡️ **[View the Full GPG Signature Guide](./signature.md)**