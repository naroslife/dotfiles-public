# Secrets Management with sops-nix

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) to securely manage secrets like API keys. Secrets are encrypted with [age](https://github.com/FiloSottile/age) and stored in the repository, then automatically decrypted during Home Manager activation.

## Automatic Setup

**Good news!** The `apply.sh` script now handles sops-nix setup **automatically**. Just run:

```bash
./apply.sh
```

The script will:

1. ✨ Detect if sops-nix configuration exists
2. 🔑 Generate Ed25519 SSH key if needed
3. 🔐 Extract age public key automatically
4. 📝 Update `.sops.yaml` with your key
5. 🎯 Create encrypted `secrets.yaml`
6. 💬 Optionally guide you through adding secrets
7. 🚀 Continue with Home Manager application

All done with clear progress indicators and full transparency!

## What Happens During Automatic Setup?

### Step 1: SSH Key Detection
The script checks for `~/.ssh/id_ed25519`. If not found:
- Detects if you have RSA keys (and explains why Ed25519 is needed)
- Offers to generate Ed25519 key automatically
- Uses your git email or prompts for one
- Creates key without passphrase (you can add one later)

### Step 2: Age Key Extraction
- Temporarily loads `ssh-to-age` via nix-shell if needed
- Converts your SSH public key to age public key
- Shows you the extracted key for transparency

### Step 3: Configuration Update
- Backs up existing `.sops.yaml`
- Replaces placeholder with your actual age key
- Updates creation rules for proper encryption

### Step 4: Secrets File Creation
- Creates encrypted `secrets.yaml` from template
- Optionally runs interactive wizard to add secrets
- Encrypts everything with your age key

### Step 5: Ready to Use
- Continues with Home Manager application
- Secrets automatically decrypted and available
- Tools permanently installed for future edits

## Manual Setup (Advanced)

If you want to understand or control each step manually:

### 1. Generate Ed25519 SSH Key

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

### 2. Get Age Public Key

```bash
nix-shell -p ssh-to-age
ssh-to-age -i ~/.ssh/id_ed25519.pub
```

### 3. Update `.sops.yaml`

Edit `.sops.yaml` and add your age public key:

```yaml
keys:
  # Age public keys for each machine/user
  - &user_naroslife age1xx32wg6juew8df7a4v33fwfxz760y4wnuwrvx86xv5v2tzlptclqupz8jp

creation_rules:
  - path_regex: ^secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *user_naroslife
```

For multiple machines, add more keys:
```yaml
keys:
  - &machine1 age1xx32wg6juew8df7a4v33fwfxz760y4wnuwrvx86xv5v2tzlptclqupz8jp
  - &machine2 age1yy43xh7kvfx9eg8b5w44gxgya871z5xovyswxy97yw6w3u0mqudmrta9kq

creation_rules:
  - path_regex: ^secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *machine1
          - *machine2  # Both machines can decrypt
```

### 4. Create Your First Encrypted Secrets File

**Initial creation** (before Home Manager is applied):

```bash
# Create and edit encrypted secrets file
SOPS_AGE_KEY_FILE=<(ssh-to-age -private-key < ~/.ssh/id_ed25519) sops secrets/secrets.yaml
```

This opens your `$EDITOR` with a blank file. Add your actual secrets:

```yaml
api_keys:
  tavily: "your-actual-tavily-key"
  morph: "your-actual-morph-key"
```

Save and exit. The file will be encrypted automatically.

**After Home Manager is applied** (step 5), you can simply use:
```bash
sops secrets/secrets.yaml
```

sops-nix will automatically find your age key via the SSH key.

### 5. Enable Validation (Optional)

Once you've created `secrets/secrets.yaml`, enable validation in `modules/secrets.nix`:

```nix
sops = {
  validateSopsFiles = true;  # Change false to true
  # ...
};
```

### 6. Apply Home Manager Configuration

```bash
# Apply home-manager configuration
./apply.sh

# Or manually:
home-manager switch --flake .#yourusername --impure
```

Your secrets are now decrypted and available as environment variables:
- `$TAVILY_API_KEY`
- `$MORPH_API_KEY`

## How It Works

### File Locations

```
dotfiles-public/
├── .sops.yaml                          # sops configuration (which keys can decrypt)
├── secrets/
│   ├── .gitignore                      # Protects unencrypted secrets
│   ├── secrets.yaml                    # Your encrypted secrets (safe to commit)
│   └── secrets.yaml.example            # Template for new secrets
├── modules/secrets.nix                 # sops-nix Home Manager configuration
└── ~/.config/api-keys/                 # Decrypted secrets (runtime only)
    ├── tavily
    └── morph
```

### Encryption Flow

1. **First-time setup**: Use `ssh-to-age` to get age public key → Add to `.sops.yaml`
2. **Initial encryption**: Use `SOPS_AGE_KEY_FILE=<(ssh-to-age -private-key < ~/.ssh/id_ed25519)` to create encrypted file
3. **After Home Manager applied**: sops-nix automatically derives age key from SSH key → No manual key management needed
4. **Editing**: `sops secrets/secrets.yaml` → Opens decrypted in editor (sops-nix finds key automatically)
5. **Saving**: sops encrypts with your age key → Safe to commit
6. **Activation**: Home Manager decrypts → Places in `~/.config/api-keys/`
7. **Usage**: Shell reads from `~/.config/api-keys/` → Sets environment variables

### How Automatic Key Management Works

The `modules/secrets.nix` configuration includes:
```nix
age = {
  sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
  generateKey = true;
}
```

This tells sops-nix to:
- Automatically derive the age decryption key from your SSH private key
- Generate the key on-the-fly when needed
- No need to manually manage age key files after initial setup

### Security Notes

- ✅ **Encrypted files** (`secrets.yaml`) are safe to commit to git
- ✅ **Age keys** are derived from SSH keys you already have
- ✅ **Decrypted secrets** only exist at runtime in `~/.config/api-keys/`
- ❌ **Never commit** unencrypted `.key` or `.txt` files (protected by `.gitignore`)

## Common Operations

### Edit Existing Secrets

```bash
sops secrets/secrets.yaml
```

### Add a New Secret

1. Edit the file:
   ```bash
   sops secrets/secrets.yaml
   ```

2. Add your secret:
   ```yaml
   api_keys:
     tavily: "existing-key"
     morph: "existing-key"
     new_service: "new-secret-here"  # Add this
   ```

3. Update `modules/secrets.nix` to expose it:
   ```nix
   secrets = {
     # ... existing secrets ...
     "api_keys/new_service" = {
       path = "${config.home.homeDirectory}/.config/api-keys/new_service";
     };
   };

   home.sessionVariables = {
     # ... existing variables ...
     NEW_SERVICE_API_KEY = "$(cat ${config.home.homeDirectory}/.config/api-keys/new_service 2>/dev/null || echo '')";
   };
   ```

4. Apply configuration:
   ```bash
   ./apply.sh
   ```

### Add Another Machine

On a second/new machine:

**Step 0: Bootstrap (if needed)**
```bash
# If you don't have ssh-to-age yet
nix-shell -p ssh-to-age age sops
```

**Step 1: Get age public key**
```bash
# Generate Ed25519 SSH key if you don't have one
ssh-keygen -t ed25519 -C "your_email@example.com"

# Get age public key
ssh-to-age -i ~/.ssh/id_ed25519.pub
```

**Step 2: Update `.sops.yaml` with the new key**
```yaml
keys:
  - &machine1 age1xx32wg6juew8df7a4v33fwfxz760y4wnuwrvx86xv5v2tzlptclqupz8jp
  - &machine2 age1yy43xh7kvfx9eg8b5w44gxgya871z5xovyswxy97yw6w3u0mqudmrta9kq  # New!

creation_rules:
  - path_regex: ^secrets/.*\.ya?ml$
    key_groups:
      - age:
          - *machine1
          - *machine2  # Add here
```

**Step 3: Re-encrypt the secrets file for the new key**
```bash
# From within nix-shell or after first apply
sops updatekeys secrets/secrets.yaml
```

**Step 4: Commit and push**
```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "Add machine2 age key to secrets"
git push
```

**Step 5: On the new machine, pull and apply**
```bash
git pull
./apply.sh
```

Now the new machine can decrypt secrets! After first apply, `ssh-to-age`, `age`, and `sops` are permanently available.

### Rotate Keys

If you need to change your age key (e.g., SSH key compromised):

```bash
# Generate new Ed25519 SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_new -C "your_email@example.com"

# Get new age public key
ssh-to-age -i ~/.ssh/id_ed25519_new.pub

# Update .sops.yaml with new public key
# Then re-encrypt with both old and new keys:
sops updatekeys secrets/secrets.yaml

# Once verified working, replace old SSH key
mv ~/.ssh/id_ed25519_new ~/.ssh/id_ed25519
mv ~/.ssh/id_ed25519_new.pub ~/.ssh/id_ed25519.pub
```

### View Encrypted File Without Editing

```bash
sops -d secrets/secrets.yaml
```

## Troubleshooting

### Error: "no key could decrypt the data"

**Cause**: Your age public key isn't in `.sops.yaml`, or the file was encrypted with different keys.

**Fix**:
1. Verify your age public key: `ssh-to-age -i ~/.ssh/id_ed25519.pub`
2. Check it matches a key in `.sops.yaml`
3. If not, add it and run: `sops updatekeys secrets/secrets.yaml`

**Note**: Don't use `age-keygen -y ~/.ssh/id_ed25519` - it doesn't work with SSH keys!

### Error: "could not find ssh key"

**Cause**: sops-nix can't find your SSH key at `~/.ssh/id_ed25519`.

**Fix**:
1. Check if the file exists: `ls -la ~/.ssh/id_ed25519`
2. If you only have RSA keys, you need Ed25519. Generate one:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
3. If your Ed25519 key is at a different path, update `modules/secrets.nix`:
   ```nix
   sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/custom_key" ];
   ```

**Important**: Age encryption requires Ed25519 keys, not RSA keys.

### Environment Variable Not Set

**Cause**: Secrets file might not be properly decrypted or Home Manager not applied.

**Fix**:
1. Check secret file exists: `ls ~/.config/api-keys/`
2. Re-apply configuration: `./apply.sh`
3. Check for errors in the output
4. Verify secret exists in `secrets.yaml`: `sops -d secrets/secrets.yaml`

### File Won't Decrypt on Another Machine

**Cause**: The new machine's age public key isn't authorized.

**Fix**: Follow "Add Another Machine" steps above.

## Quick Reference

### Common Commands

```bash
# First-time setup (automatic)
./apply.sh

# Edit secrets (after setup)
sops secrets/secrets.yaml

# View decrypted secrets without editing
sops -d secrets/secrets.yaml

# Add new machine's age key
ssh-to-age -i ~/.ssh/id_ed25519.pub  # On new machine
# Add key to .sops.yaml, then:
sops updatekeys secrets/secrets.yaml

# Add passphrase to SSH key (optional)
ssh-keygen -p -f ~/.ssh/id_ed25519
```

### Environment Variables Available

After `./apply.sh` completes, secrets are available as:

```bash
echo $TAVILY_API_KEY
echo $MORPH_API_KEY
```

### File Locations

```
~/.ssh/id_ed25519              # SSH private key (also used for age)
~/.ssh/id_ed25519.pub          # SSH public key
.sops.yaml                      # Encryption configuration (committed)
secrets/secrets.yaml            # Encrypted secrets (committed)
~/.config/api-keys/             # Decrypted secrets (runtime only)
```

### Automatic Bootstrap Behavior

The `apply.sh` script **automatically**:
- ✅ Detects sops-nix configuration
- ✅ Loads required tools if missing
- ✅ Generates SSH key if needed
- ✅ Extracts and configures age key
- ✅ Creates encrypted secrets file
- ✅ Prompts for secrets (optional)

**No manual steps required!** Just run `./apply.sh`

## Advanced Usage

### Per-User Secrets

To have different secrets for different users (e.g., `naroslife` vs `enterpriseuser`):

```yaml
# .sops.yaml
keys:
  - &user_naros age1111...
  - &user_enterprise age2222...

creation_rules:
  - path_regex: secrets/naroslife\.yaml$
    key_groups:
      - age:
          - *user_naros

  - path_regex: secrets/enterpriseuser\.yaml$
    key_groups:
      - age:
          - *user_enterprise
```

Then update `modules/secrets.nix` to use different files based on username.

### Integration with Other Tools

The decrypted secrets in `~/.config/api-keys/` can be used by any tool:

```bash
# Direct file reading
curl -H "Authorization: Bearer $(cat ~/.config/api-keys/tavily)" https://api.example.com

# Environment variable
export TAVILY_API_KEY=$(cat ~/.config/api-keys/tavily)
```

## References

- [sops-nix Documentation](https://github.com/Mic92/sops-nix)
- [age Encryption Tool](https://github.com/FiloSottile/age)
- [Mozilla SOPS](https://github.com/mozilla/sops)
