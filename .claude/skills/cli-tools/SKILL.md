---
name: cli-tools
description: "Use when a command fails with 'command not found', or when installing CLI tools (ripgrep, fd, jq, yq, bat, etc.), auditing project environments, or batch-updating tools. Triggers on: command not found, install tool, missing binary, environment audit, update tools, which, apt install, brew install."
---

# CLI Tools Skill

Install, audit, update, and recommend CLI tools. Covers 74+ common development tools.

## Triggers

- **Reactive**: `command not found` errors -- auto-resolve
- **Proactive**: "check environment", "install X", "update tools"
- **Advisory**: Recommend modern alternatives (`grep`->`rg`, `find`->`fd`, JSON->`jq`)

## Preferred Modern Tools

Recommend over legacy equivalents:

| Legacy | Modern | Legacy | Modern |
|--------|--------|--------|--------|
| `grep -r` | `rg` (ripgrep) | `diff` | `difft` (difftastic) |
| `find` | `fd` | `time` | `hyperfine` |
| grep on JSON | `jq` | `cat` | `bat` |
| sed on YAML | `yq` | `cloc` | `tokei`/`scc` |
| awk on CSV | `qsv` / `miller` | `ls` | `eza` |
| `du` | `dust` | `df` | `duf` |
| `ps` | `procs` | `top`/`htop` | `btm` (bottom) |
| `ping` | `gping` | `dig` | `dog` |
| `curl` (for HTTP) | `xh` | `cd` | `z` (zoxide) |

## Missing Tool Resolution Workflow

### 1. Diagnose
```bash
which <tool>
command -v <tool>
type -a <tool>
```

### 2. Check binary name mapping

Some tools have different binary vs package names:

| Binary | Package/Tool |
|--------|-------------|
| `rg` | `ripgrep` |
| `fd` | `fd-find` (apt) / `fd` (cargo/mise) |
| `batcat` | `bat` (Debian/Ubuntu apt uses `batcat`) |
| `fdfind` | `fd-find` (Debian/Ubuntu apt) |
| `btm` | `bottom` |
| `difft` | `difftastic` |
| `delta` | `git-delta` |

### 3. Install (priority order)

1. **mise** (preferred for dev tools): `mise use -g "aqua:sharkdp/bat"` or `mise use -g "aqua:BurntSushi/ripgrep"` (use `github:` if not in aqua registry)
2. **GitHub Release Binary**: Download from releases, extract to `~/.local/bin/`
3. **cargo**: `cargo install <tool>` (if Rust is available)
4. **pipx**: `pipx install <tool>` (Python tools)
5. **npm**: `npm install -g <tool>` (Node tools)
6. **apt**: `sudo apt install <tool>` (system packages, may be older versions)

### 4. Verify
```bash
which <tool>
<tool> --version
```

If installed but not found:
```bash
hash -r                           # clear bash's command cache
echo $PATH                        # check PATH includes install dir
ls ~/.local/bin/ ~/.cargo/bin/     # check common install directories
```

## Installation by Category

### Rust-based tools (fast, single binary)
Best installed via mise `aqua:` backend (or `github:` fallback) or `cargo install`:
- bat, eza, fd, ripgrep, zoxide, dust, duf, procs, bottom
- delta, difftastic, tokei, scc, xh, gping, dog
- lazygit, gitui, broot, tealdeer

### Python-based tools
Best installed via `pipx`:
- httpie, visidata, ranger-fm, pgcli, pre-commit, black, mypy

### Go-based tools
Best installed via mise or `go install`:
- lazydocker, k9s, yq, cheat, navi, usql

### System tools (need apt)
- git, gcc, g++, make, cmake, gdb, valgrind, strace
- nmap, wireshark, mosh, tmux, zsh
- curl, wget, rsync, ssh

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Installed but `command not found` | `hash -r` or add install dir to PATH |
| No sudo access | Use `cargo install`, `pip install --user`, or manual binary in `~/.local/bin/` |
| Debian `bat`=`batcat` | `ln -s /usr/bin/batcat ~/.local/bin/bat` |
| Debian `fd`=`fdfind` | `ln -s /usr/bin/fdfind ~/.local/bin/fd` |
| Old version via apt | Install via mise or cargo for latest version |
| Permission denied | Check file is executable: `chmod +x ~/.local/bin/<tool>` |

## Environment Audit

Quick check for essential development tools:
```bash
for tool in git gcc make cmake python3 node go rustc docker; do
  if command -v "$tool" &>/dev/null; then
    echo "[OK] $tool: $($tool --version 2>&1 | head -1)"
  else
    echo "[MISSING] $tool"
  fi
done
```

## PATH Configuration

Standard directories that should be in PATH (in priority order):
```
~/.local/bin            # User binaries, manual installs
~/.cargo/bin            # Rust/cargo tools
~/go/bin                # Go tools
~/.npm-global/bin       # Global npm packages
~/.local/share/mise/shims  # mise shims (if using shim mode)
/usr/local/bin          # System-wide local installs
/usr/bin                # System packages
```
