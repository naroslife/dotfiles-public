# VSCode Extension Selector

Interactive TUI tool for selecting VSCode extensions for your workspace.

## Usage

```bash
# Python version (recommended)
./scripts/vscode-extension-selector.py

# Bash version (fallback)
./scripts/vscode-extension-selector.sh.bak
```

## Features

- **Modern TUI**: Built with Python Textual framework for rich terminal UI
- **Category Organization**: Collapsible tree view with active/total counts per category
- **Smart Status Indicators**:
  - `✓` = Currently active in extensions.json
  - `#` = Commented out in extensions.json
  - `○` = Not configured
- **Live Preview Panel**: Right column shows extension details as you navigate
- **Checkboxes**: Clear visual indication of selection state
- **Commented Extensions**: Previously commented extensions are preserved
- **Automatic Backup**: Creates timestamped backup before making changes
- **Keyboard Navigation**: Intuitive shortcuts for all operations

## Display Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ 🎨 VSCode Extension Selector                                    │
├────────────────────────────┬────────────────────────────────────┤
│ Extensions (105 total)     │ Preview                            │
│                            │                                    │
│ ▼ Language [15/20]        │ Extension: ms-python.python        │
│   [✓] ms-python.python    │ Category: Language                 │
│   [ ] ms-vscode.powershell│ Status: ✓ Currently Active        │
│   [✓] rust-lang.rust-...  │                                    │
│                            │ Description:                       │
│ ▼ Git [5/8]              │ Python language support with       │
│   [✓] eamodio.gitlens     │ IntelliSense, linting, debugging   │
│   [ ] github.vscode-pu... │                                    │
│                            │ Nix: ms-python.python             │
├────────────────────────────┴────────────────────────────────────┤
│ Space:Toggle  Enter:Save  q:Quit  a:All  d:None                │
└─────────────────────────────────────────────────────────────────┘
```

## Key Bindings

- `Space` - Toggle checkbox for current extension
- `Enter` / `s` - Save selection and exit
- `q` / `Escape` - Quit without saving
- `a` - Select all extensions
- `d` - Deselect all extensions
- `Arrow Keys` - Navigate tree
- `↑/↓` - Move up/down
- `←/→` - Collapse/expand categories

## Python vs Bash Version

### Python Version (Recommended)
- Modern, intuitive TUI with Textual framework
- Collapsible categories, checkboxes, rich formatting
- Live preview panel with extension details
- Easier to navigate and understand
- More maintainable codebase

### Bash Version (Fallback)
- Uses fzf for selection
- Lightweight, minimal dependencies
- Available as `.sh.bak` for systems without Python/Textual

## How It Works

1. **Reads Current Configuration**: Parses `.vscode/extensions.json` to identify:
   - Active extensions (non-commented)
   - Commented extensions (disabled but preserved)

2. **Interactive Selection**: Shows all available extensions with status indicators

3. **Generates Organized Output**:
   - Groups selected extensions by category
   - Preserves commented extensions at the end
   - Maintains clean JSON formatting

## Extension Sources

The tool uses:
- `.vscode/extensions.json` - Current VSCode recommendations
- `vscode-extension-data.json` - Extension metadata (categories, descriptions)

## Output

Updates `.vscode/extensions.json` with:
- Selected extensions grouped by category
- Optional/disabled extensions commented at the end
- Proper formatting and documentation

## Changes from Previous Version

- **No Nix Integration**: Extensions are managed solely through extensions.json
- **Improved Status Display**: Shows active, commented, and new extensions clearly
- **Category Preservation**: Maintains logical grouping of extensions
- **Comment Handling**: Properly detects and preserves commented extensions

## Extension Availability

- Extensions marked with `✓ nix` are available in nixpkgs
- Extensions marked with `✗ not-in-nixpkgs` need manual installation via VSCode

## Configuration

Set custom extensions.json location:
```bash
EXTENSIONS_JSON=/path/to/extensions.json ./scripts/vscode-extension-selector.sh
```

## Data File

Extension metadata is stored in `scripts/vscode-extension-data.json`:
- VSCode marketplace IDs
- Nix package names (if available)
- Descriptions and categories
- Availability status

To add new extensions, edit this file with:
```json
{
  "id": "publisher.extension-name",
  "nix": "nix-package-name",
  "description": "Extension description",
  "category": "language|formatter|git|productivity|themes|remote|containers|testing|ai"
}
```

If an extension is not in nixpkgs, set `"nix": null`.
