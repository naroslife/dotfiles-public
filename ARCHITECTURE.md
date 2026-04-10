# Dotfiles Architecture

> **Migration in progress**: Transitioning from Nix + Home Manager to chezmoi + mise.
> See [ADR-001](docs/adr/ADR-001-chezmoi-mise-migration.md) for the full decision record.
> Issue dependency graph: [#20](https://github.com/naroslife/dotfiles-public/issues/20)

## Target Architecture (chezmoi + mise)

### Directory Structure

```
dotfiles-public/
├── .chezmoi.toml.tmpl          # chezmoi config template (per-machine)
├── .chezmoiignore              # Per-machine file exclusion
├── .chezmoiexternal.toml       # External repos (zsh plugins, tpm)
├── .chezmoidata/
│   ├── packages.yaml           # Tool inventory by tier
│   └── users.yaml              # User profiles (naroslife, enterpriseuser)
├── .mise.toml                  # Global tool versions (Tier 1/2)
├── bootstrap.sh                # Entry point: installs chezmoi + mise + tools
├── deploy-remote.sh            # Offline deployment to restricted machines
├── home/                       # chezmoi source directory
│   ├── dot_zshrc.tmpl          # Zsh config (Go template, machine-aware)
│   ├── dot_gitconfig.tmpl      # Git config (template per user)
│   ├── dot_ssh/
│   │   └── config.tmpl         # SSH config (enterprise vs personal)
│   ├── dot_config/
│   │   ├── starship.toml       # Prompt config
│   │   ├── atuin/config.toml   # History manager config
│   │   ├── bottom/bottom.toml  # btm (top replacement) config
│   │   ├── ripgrep/config      # rg config
│   │   └── (nvim/, tmux/, carapace/ — added in later phases)
│   └── run_onchange_*.sh.tmpl  # Bootstrap hooks (zsh plugins, etc.)
├── scripts/
│   ├── install-apt-deps.sh     # Tier 3/4 apt dependencies
│   ├── install-zsh-plugins.sh  # Zsh plugin git clones
│   ├── install-fonts.sh        # Nerd Fonts download
│   └── kill-switch.sh          # Revert all modern CLI aliases
├── docs/
│   └── adr/
│       └── ADR-001-chezmoi-mise-migration.md
├── tests/                      # Test suite
├── wsl-fixes/                  # WSL-specific helpers
└── .github/workflows/          # CI/CD
```

### Core Components

#### chezmoi (Dotfile Manager)
- **Templates**: Go template syntax for machine-specific config (WSL vs native, naroslife vs enterpriseuser)
- **Encryption**: Built-in age encryption for secrets (replaces sops-nix)
- **Run scripts**: `run_once_` and `run_onchange_` hooks for bootstrapping
- **External sources**: `.chezmoiexternal.toml` manages plugin git clones
- **Data files**: `.chezmoidata/` provides variables to templates

#### mise-en-place (Tool Manager)
- **Backends**: ubi (universal binary), pipx, cargo, npm, and more
- **Offline mode**: `mise lock` pins download URLs; `always_keep_download` caches
- **Task runner**: Built-in `[tasks]` replaces Makefile/scripts
- **Auto env vars**: Sets `JAVA_HOME`, `GOPATH`, etc. automatically
- **Activation**: `eval "$(mise activate zsh)"` in `.zshrc`

#### Kill Switch System
All modern CLI alias overrides are gated:
```bash
if [[ -z "${DOTFILES_NO_ALIASES:-}" ]]; then
  alias cat='bat'
  alias ls='eza'
  # ... etc
fi
```
`scripts/kill-switch.sh` (sourceable) exports `DOTFILES_NO_ALIASES=1` and unaliases everything.

### Tool Tier Classification

| Tier | Description | Install Method | Examples |
|------|-------------|----------------|---------|
| **1** | Standalone binaries, alias/PATH swap | `mise ubi/pipx/cargo` | bat, eza, fd, ripgrep, lazygit, gh, k9s |
| **2** | Binaries with config/data files | mise + chezmoi templates | starship, atuin, tmux, neovim, git, zsh |
| **3** | Complex toolchains, internal path resolution | apt (preferred) + mise for JVM/Go/Node/Rust | GDB, GCC, JDK, Maven, Go, Node, Rust |
| **4** | Container/platform-managed only | apt/snap/docker — documented as prerequisites | Docker daemon, wireshark, CUDA, WSL utils |

### Multi-User Support

Configured via `.chezmoidata/users.yaml` and Go templates:
```toml
# .chezmoi.toml.tmpl
[data]
  is_enterprise = {{ eq .chezmoi.username "enterpriseuser" }}
  is_personal   = {{ eq .chezmoi.username "naroslife" }}
```

Templates conditionally include enterprise-specific config:
```
{{ if .is_enterprise }}
# enterprise-specific content
{{ end }}
```

### Offline Deployment

Three deployment scenarios supported by `deploy-remote.sh`:

1. **Proxy**: `export HTTPS_PROXY=...` → `./bootstrap.sh`
2. **Air-gapped**: `mise lock` + cache bundle → `./bootstrap.sh --offline`
3. **No root**: mise installs to `~/.local/bin`; skip apt with `--no-apt`

---

## Legacy Architecture (Nix + Home Manager)

> These files remain during Phase 1 of migration (non-destructive). They will be removed in Phase 5.

### Project Structure (Legacy)

```
dotfiles-public/
├── lib/
│   └── common.sh              # Shared utility library
├── tests/
│   ├── test_common.sh         # Library tests
│   ├── test_apply.sh          # Apply script tests
│   └── run_tests.sh           # Test runner
├── scripts/                   # Utility scripts
├── apply.sh                   # Nix Home Manager setup script
├── flake.nix                  # Nix flake configuration
├── home.nix                   # Home Manager entry point
└── modules/                   # Nix modules (cli/, dev/, shells/, etc.)
```

### Core Components (Legacy)

#### Shared Library (`lib/common.sh`)
- **Logging**: Structured logging with ERROR, WARN, INFO, DEBUG levels
- **Platform Detection**: Linux, WSL, macOS identification
- **Error Handling**: Comprehensive recovery and backup support
- **Security**: URL fetching with checksum verification

#### Main Setup Script (`apply.sh`)
- **Nix Management**: Installation and configuration
- **Multi-user Support**: User selection via flakes
- **Platform Optimization**: WSL-specific enhancements
- **Error Recovery**: Automatic backups and rollback

#### Test Suite (`tests/`)
- 30+ test cases covering all major functions
- Performance benchmarking
- Mock environment testing

---

## Migration Status

| Phase | Issues | Status |
|-------|--------|--------|
| Phase 1: Foundation | #20 (this PR) | In Progress |
| Phase 2: Tools & Configs | #21, #22, #25, #28 | Pending |
| Phase 3: Shell & Features | #23, #26, #27, #29, #30, #31, #32 | Pending |
| Phase 4: Quality & Docs | #33, #34 | Pending |
| Phase 5: Remove Nix | — | Pending |

See [issue #20](https://github.com/naroslife/dotfiles-public/issues/20) for the full dependency graph.
