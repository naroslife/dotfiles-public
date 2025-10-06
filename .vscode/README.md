# VSCode Configuration

This directory contains VSCode configuration files for use with Remote-SSH and WSL connections.

## Files

- **extensions.json** - List of recommended extensions for the workspace
- **settings.json** - VSCode user settings that will be applied
- **keybindings.json** - Custom keybindings

## Usage

### For Remote Development (SSH/WSL)

When you connect to a remote Linux machine or WSL from VSCode on Windows:

1. **Extensions**: VSCode will automatically suggest installing the extensions listed in `extensions.json`
2. **Settings**: Copy settings from `settings.json` to your user settings:
   - Windows: `%APPDATA%\Code\User\settings.json`
   - Remote/WSL: Settings sync or manual copy to `~/.config/Code/User/settings.json`
3. **Keybindings**: Copy keybindings from `keybindings.json` to:
   - Windows: `%APPDATA%\Code\User\keybindings.json`
   - Remote/WSL: `~/.config/Code/User/keybindings.json`

### Settings Sync

For the best experience, enable Settings Sync in VSCode:
1. Sign in with GitHub or Microsoft account
2. Enable Settings Sync
3. Your settings will automatically sync across all your VSCode instances

### Why No Nix Package?

Since you're connecting from Windows to Linux remotes or WSL:
- VSCode runs on Windows (not managed by Nix)
- VSCode Server is automatically installed on the remote when you connect
- Extensions and settings are managed through VSCode's built-in mechanisms
- This approach ensures compatibility with VSCode's remote development workflow

## Customization

Feel free to modify these files to suit your preferences. The configuration includes:
- Modern editor features (sticky scroll, bracket colorization)
- Language-specific settings for Python, JavaScript, Rust, Nix, etc.
- Optimized remote development settings
- Performance optimizations (file watcher exclusions)
- Productivity keybindings