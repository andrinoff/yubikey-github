# Full YubiKey GPG Setup for GitHub Commit Signing

This guide provides a comprehensive tutorial on how to set up a YubiKey to sign your Git commits on GitHub using GPG (GnuPG). This ensures that commits attributed to you were indeed made by you, adding a layer of trust and security. A signature will require a physical touch on your YubiKey.

### **Prerequisites**

1.  **A YubiKey:** Any YubiKey from the 4 or 5 Series that supports the OpenPGP feature.
2.  **Git:** Installed on your system.
3.  **GnuPG:** The software for managing GPG keys.

---

## Step 1: Install GnuPG

* **Windows:**
    Download and install **Gpg4win** from the official website: [gpg4win.org](https://www.gpg4win.org/). This package includes GnuPG, the Kleopatra key manager, and other useful tools.

* **macOS:**
    The easiest way is to use Homebrew. Open your Terminal and run:
    ```bash
    brew install gnupg yubikey-personalization
    ```
    You may also want `pinentry-mac`, a tool for entering PINs in a native macOS dialog:
    ```bash
    brew install pinentry-mac
    # Configure gpg-agent to use it
    echo "pinentry-program /usr/local/bin/pinentry-mac" >> ~/.gnupg/gpg-agent.conf
    gpg-connect-agent reloadagent /bye
    ```

* **Linux (Debian/Ubuntu):**
    GnuPG is typically pre-installed. If not, you can install it and the necessary tools:
    ```bash
    sudo apt update
    sudo apt install gnupg2 pcscd scdaemon
    ```

---

## Step 2: Prepare Your YubiKey and Generate Keys

For maximum security, we will generate the GPG keys directly on the YubiKey itself. This means the private keys never touch your computer's hard drive.

1.  **Insert your YubiKey.**

2.  **Reset the OpenPGP applet (Optional but Recommended for a clean start):**
    **WARNING: This will delete any existing GPG keys on the YubiKey.**
    ```bash
    gpg --card-edit
    # In the gpg/card> prompt:
    admin
    factory-reset
    # Confirm the reset. It will wipe the OpenPGP applet.
    quit
    ```

3.  **Change Default PINs:**
    The default PINs are weak and must be changed.
    * **Default User PIN:** `123456`
    * **Default Admin PIN:** `12345678`

    Run `gpg --card-edit` again to enter the card management prompt.
    ```bash
    gpg --card-edit
    # In the gpg/card> prompt:
    admin
    passwd
    # Select option 1 to change the User PIN.
    # Enter the default PIN (123456), then your new PIN.
    # Select option 3 to change the Admin PIN.
    # Enter the default Admin PIN (12345678), then your new Admin PIN.
    # A good PIN is at least 8 characters. The Admin PIN should be longer/more complex.
    quit
    ```

4.  **Generate the Keys on the YubiKey:**
    Run `gpg --card-edit` one more time.
    ```bash
    gpg --card-edit
    # In the gpg/card> prompt:
    admin
    generate
    # It will ask if you want to make an off-card backup of the encryption key.
    # For maximum security, say No (n).
    # It will prompt for key expiry. Choose a reasonable value (e.g., 2y for 2 years) or never.
    # Enter your Real Name, Email Address, and an optional Comment.
    # Confirm the details are correct by typing 'O' for Okay.
    # You will be prompted for your Admin PIN, then your User PIN.
    quit
    ```
    GnuPG has now generated three keys (Signature, Encryption, Authentication) directly on your YubiKey.

---

## Step 3: Set Up Signature by Touch

This policy requires you to physically touch your YubiKey for every signature, preventing malware from signing commits without your presence.

1.  **Find your Key's "Key-ID":**
    Run `gpg --card-status`. Look for the "Signature key" line. The long string of characters is the Key-ID.
    ```
    Signature key ....: E4A1 C325 45E6 4A9C 1E80  0C5B 2E3E F53B 5882 732D
    ```
    In this example, the Key-ID is `E4A1C32545E64A9C1E800C5B2E3EF53B5882732D`.

2.  **Edit the Key to Set Touch Policy:**
    ```bash
    gpg --edit-key YOUR_KEY_ID
    # In the gpg> prompt:
    toggle
    key 1
    # You should now see an asterisk (*) next to the signature key.
    keytocard
    # Select option 1 (Signature key).
    # Enter your User PIN.
    save
    ```
    The touch policy is now set for the signature key.

---

## Step 4: Add Your GPG Public Key to GitHub

1.  **Export your GPG public key:**
    First, get your GPG key ID (the short version is fine).
    ```bash
    gpg --list-secret-keys --keyid-format=long
    ```
    The output will show your key. The ID is the part after `sec> rsa4096/`.
    ```
    sec>  rsa4096/AABBCCDD11223344 2025-07-14 [SC]
    ```
    Now export the public key for that ID in the correct format.
    ```bash
    gpg --armor --export AABBCCDD11223344
    ```

2.  **Copy the entire output**, including the `-----BEGIN PGP PUBLIC KEY BLOCK-----` and `-----END PGP PUBLIC KEY BLOCK-----` lines.

3.  **Add the key to GitHub:**
    * Go to your GitHub **Settings**.
    * In the "Access" section, click **SSH and GPG keys**.
    * Click the **New GPG key** button.
    * Paste your public key block into the **Key** field.
    * Click **Add GPG key**.

---

## Step 5: Configure Git to Use Your GPG Key

1.  **Tell Git which key to use:**
    Use the same GPG key ID from the previous step.
    ```bash
    git config --global user.signingkey AABBCCDD11223344
    ```

2.  **Tell Git to sign all commits automatically:**
    ```bash
    git config --global commit.gpgsign true
    ```

3.  **(For macOS/Linux) Ensure Git uses the right GPG program:**
    ```bash
    git config --global gpg.program $(which gpg)
    ```

Now, when you run `git commit`, you will be prompted for your YubiKey PIN, and the key will start flashing. Touch it to create the signature. When you push to GitHub, your commits will have a "Verified" badge.
