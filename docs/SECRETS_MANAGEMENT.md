# Secrets Management with sops-nix

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) to securely manage secrets like API keys. Secrets are encrypted with [age](https://github.com/FiloSottile/age) and stored in the repository, then automatically decrypted during Home Manager activation.

## Quick Start

### 1. Generate Age Key (One-Time Setup)

On each machine where you want to use secrets:

```bash
# Generate age public key from your SSH key
age-keygen -y ~/.ssh/id_ed25519

# Output will look like: age1234567890abcdefghijklmnopqrstuvwxyz...
# Copy this public key!
```

If you don't have an SSH key yet:
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Then run the age-keygen command above
```

### 2. Update `.sops.yaml`

Edit `.sops.yaml` and replace `YOUR_AGE_PUBLIC_KEY_HERE` with your age public key:

```yaml
keys:
  - &main_user age1234567890abcdefghijklmnopqrstuvwxyz...  # Replace this!
```

For multiple machines, add more keys:
```yaml
keys:
  - &machine1 age1234567890abcdefghijklmnopqrstuvwxyz...
  - &machine2 age0987654321zyxwvutsrqponmlkjihgfedcba...

creation_rules:
  - path_regex: secrets/secrets\.yaml$
    key_groups:
      - age:
          - *machine1
          - *machine2  # Both machines can decrypt
```

### 3. Create Your Secrets File

```bash
# Copy the example template
cp secrets/secrets.yaml.example secrets/secrets.yaml

# Edit with sops (will encrypt automatically on save)
sops secrets/secrets.yaml
```

This opens your `$EDITOR` with decrypted content. Add your actual secrets:

```yaml
api_keys:
  tavily: "sk-actual-tavily-key-here"
  morph: "mk-actual-morph-key-here"
```

Save and exit. The file will be encrypted automatically.

### 4. Enable Validation (Optional)

Once you've created `secrets/secrets.yaml`, enable validation in `modules/secrets.nix`:

```nix
sops = {
  validateSopsFiles = true;  # Change false to true
  # ...
};
```

### 5. Apply Configuration

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

1. **Editing**: `sops secrets/secrets.yaml` → Opens decrypted in editor
2. **Saving**: sops encrypts with your age key → Safe to commit
3. **Activation**: Home Manager decrypts → Places in `~/.config/api-keys/`
4. **Usage**: Shell reads from `~/.config/api-keys/` → Sets environment variables

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

1. On the new machine, get the age public key:
   ```bash
   age-keygen -y ~/.ssh/id_ed25519
   ```

2. Update `.sops.yaml` with the new key:
   ```yaml
   keys:
     - &machine1 age1111111111111111111111111111111111111111111111111111111111
     - &machine2 age2222222222222222222222222222222222222222222222222222222222  # New!

   creation_rules:
     - path_regex: secrets/secrets\.yaml$
       key_groups:
         - age:
             - *machine1
             - *machine2  # Add here
   ```

3. Re-encrypt the secrets file for the new key:
   ```bash
   sops updatekeys secrets/secrets.yaml
   ```

4. Commit and push the updated `secrets.yaml` and `.sops.yaml`

5. On the new machine, pull and apply:
   ```bash
   git pull
   ./apply.sh
   ```

### Rotate Keys

If you need to change your age key:

```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/keys.txt

# Get public key
age-keygen -y ~/.config/sops/age/keys.txt

# Update .sops.yaml with new public key
# Then re-encrypt:
sops updatekeys secrets/secrets.yaml
```

### View Encrypted File Without Editing

```bash
sops -d secrets/secrets.yaml
```

## Troubleshooting

### Error: "no key could decrypt the data"

**Cause**: Your age public key isn't in `.sops.yaml`, or the file was encrypted with different keys.

**Fix**:
1. Verify your age public key: `age-keygen -y ~/.ssh/id_ed25519`
2. Check it matches a key in `.sops.yaml`
3. If not, add it and run: `sops updatekeys secrets/secrets.yaml`

### Error: "could not find ssh key"

**Cause**: sops can't find your SSH key at `~/.ssh/id_ed25519`.

**Fix**:
1. Check if the file exists: `ls -la ~/.ssh/id_ed25519`
2. Update `modules/secrets.nix` to point to your actual SSH key path:
   ```nix
   sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_rsa" ];
   ```

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
