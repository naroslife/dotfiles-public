# Interactive User Configuration

The dotfiles setup now includes an interactive configuration system that allows users to input their specific settings during installation, rather than editing configuration files manually.

## Features

### 🎯 **What Can Be Configured**

- **Personal Information**
  - Username
  - Full name for Git commits
  - Email address

- **Development Settings**
  - Git signing key (optional)
  - Default shell (bash, zsh, fish, elvish)
  - Default editor (vim, nvim, emacs, nano, code)

- **Environment Configuration**
  - Timezone
  - Corporate test IPs (for network testing)
  - Proxy settings (HTTP/HTTPS/no-proxy)

## Usage

### Interactive Mode

Run the setup with the interactive flag:

```bash
./apply.sh --interactive
```

Or during normal setup, you'll be prompted:

```bash
./apply.sh
# You'll be asked: "Would you like to configure user-specific settings?"
```

### Configuration Flow

The interactive wizard guides you through each setting:

```
🔧 Starting interactive user configuration
========================================

This wizard will help you configure user-specific settings for your dotfiles.
Press Enter to accept default values shown in brackets.

Username Configuration
---------------------
Enter your username [current_user]: john

Git Configuration
----------------
Enter your full name for Git commits: John Doe
Enter your email for Git commits: john@example.com
Do you want to configure Git commit signing? [y/N]: n

Shell Preferences
----------------
Available shells: bash, zsh, fish, elvish
Choose your default shell [bash]: zsh

Available editors: vim, nvim, emacs, nano, code
Choose your default editor [vim]: nvim

Enter your timezone [UTC]: America/New_York

Environment Configuration
------------------------
Do you have corporate test IPs to configure? [y/N]: y
Enter corporate test IPs (comma-separated): 192.168.1.100,10.0.0.50

Do you need to configure a proxy? [y/N]: n
```

### Configuration Storage

Your settings are saved in two locations:

1. **Shell Configuration**: `~/.config/dotfiles/user.conf`
   - Bash-compatible format
   - Used by shell scripts
   - Secure permissions (600)

2. **Nix Configuration**: `~/.config/dotfiles/user.nix`
   - Nix expression format
   - Imported by Home Manager
   - Applied to your environment

## Configuration Options

### Required Settings

| Setting | Description | Example | Validation |
|---------|-------------|---------|------------|
| **Username** | System username | `john` | Letters, numbers, underscores, hyphens |
| **Git Name** | Full name for commits | `John Doe` | At least 2 characters |
| **Git Email** | Email for commits | `john@example.com` | Valid email format |
| **Shell** | Default shell | `zsh` | bash, zsh, fish, elvish |
| **Editor** | Default editor | `nvim` | vim, nvim, emacs, nano, code |
| **Timezone** | System timezone | `America/New_York` | Valid timezone string |

### Optional Settings

| Setting | Description | Example | When to Use |
|---------|-------------|---------|-------------|
| **Git Signing Key** | GPG key ID | `ABCD1234` | If you sign commits |
| **Corp Test IPs** | Test IP addresses | `192.168.1.1,10.0.0.1` | Corporate environments |
| **HTTP Proxy** | HTTP proxy URL | `http://proxy:8080` | Behind corporate proxy |
| **HTTPS Proxy** | HTTPS proxy URL | `https://proxy:8443` | Behind corporate proxy |
| **No Proxy** | Bypass proxy domains | `localhost,*.local` | Proxy exceptions |

## Integration with Nix

The configuration is automatically integrated with your Nix/Home Manager setup:

### Git Configuration
Your Git settings are applied via `programs.git`:
```nix
programs.git = {
  userName = "John Doe";
  userEmail = "john@example.com";
};
```

### Environment Variables
Settings are exported as environment variables:
```bash
EDITOR=nvim
TZ=America/New_York
CORP_TEST_IPS=192.168.1.100,10.0.0.50
```

### Shell Selection
Your chosen shell is enabled:
```nix
programs.zsh.enable = true;  # If you chose zsh
```

## Managing Configuration

### Update Existing Configuration

Re-run the interactive setup:
```bash
./apply.sh --interactive
```

You'll see your current settings and can choose to update them.

### Manual Editing

Edit the configuration file directly:
```bash
vim ~/.config/dotfiles/user.conf
```

Then regenerate the Nix configuration:
```bash
./apply.sh
```

### Command-Line Access

Get a specific value:
```bash
source lib/user_config.sh
get_config_value "git_email"
```

Set a specific value:
```bash
source lib/user_config.sh
set_config_value "editor" "code"
```

## Non-Interactive Mode

For automated deployments, you can pre-create the configuration:

```bash
# Create configuration directory
mkdir -p ~/.config/dotfiles

# Create user.conf
cat > ~/.config/dotfiles/user.conf << EOF
USER_CONFIG[username]="john"
USER_CONFIG[git_name]="John Doe"
USER_CONFIG[git_email]="john@example.com"
USER_CONFIG[shell]="zsh"
USER_CONFIG[editor]="nvim"
USER_CONFIG[timezone]="America/New_York"
EOF

# Run setup in non-interactive mode
./apply.sh --yes
```

## Testing

Test the configuration module:
```bash
./tests/test_user_config.sh
```

Test the complete setup with configuration:
```bash
./tests/run_tests.sh --verbose
```

## Troubleshooting

### Configuration Not Applied

**Problem**: Settings don't seem to take effect

**Solution**:
1. Verify configuration files exist:
   ```bash
   ls -la ~/.config/dotfiles/
   ```
2. Re-run Home Manager:
   ```bash
   ./apply.sh
   ```
3. Source your shell configuration:
   ```bash
   source ~/.bashrc
   ```

### Invalid Input

**Problem**: Configuration wizard rejects input

**Solution**: Check validation rules:
- Username: lowercase letters, numbers, underscores, hyphens
- Email: standard email format
- IPs: Valid IPv4 addresses

### Permission Issues

**Problem**: Can't save configuration

**Solution**: Ensure you have write permissions:
```bash
mkdir -p ~/.config/dotfiles
chmod 755 ~/.config/dotfiles
```

## Security Considerations

- Configuration files have restricted permissions (600)
- Sensitive data (like proxy passwords) should use environment variables
- GPG keys are referenced by ID only, not stored
- No secrets are committed to the repository

## Benefits

1. **No Manual Editing**: No need to edit Nix files directly
2. **Validation**: Input is validated before saving
3. **Portable**: Configuration can be backed up and restored
4. **Flexible**: Works with both interactive and automated setups
5. **Integrated**: Seamlessly works with Nix and Home Manager