# ADR-001: Migrate Dotfiles from Nix/Home Manager to chezmoi + mise

**Status**: Accepted
**Date**: 2026-04-09
**Issue**: #20

## Context

The dotfiles repository uses Nix + Home Manager for reproducible environment management. While powerful, Nix introduces complexity that conflicts with real-world constraints:

1. **Restricted deployment environments** — corporate machines cannot install Nix (kernel requirements, network restrictions, admin policy)
2. **Startup overhead** — Nix's evaluation adds latency to shell startup
3. **Cognitive complexity** — Nix is a specialized language; the entire team must know it
4. **Offline deployment friction** — While possible, Nix offline deployment is complex (closure copy, NAR archives)
5. **Shell framework** — Elvish is dropped per requirements; only Zsh/Bash needed

The goal is to replace Nix + Home Manager with a stack that:
- Deploys to stock Ubuntu (apt + internet, or fully offline)
- Manages dotfiles with machine-specific templating
- Installs tools reproducibly without root/kernel requirements
- Handles secrets via encryption (not sops-nix)

## Decision

### Dotfile Management: chezmoi

**Why chezmoi over alternatives:**

| Criteria | chezmoi | Bare git repo | GNU stow |
|----------|---------|---------------|----------|
| Templates (machine-specific configs) | Go templates | No | No |
| Built-in encryption (age/gpg) | Yes | No | No |
| Run scripts (bootstrap hooks) | `run_once_`, `run_onchange_` | Manual | Manual |
| One-command apply | `chezmoi apply` | Manual | `stow .` |
| Multi-user configs | `.chezmoidata/` + templates | Git branches | Separate dirs |

chezmoi's template system directly replaces Nix's module pattern for machine-specific configuration (WSL vs native, naroslife vs enterpriseuser). Built-in age encryption replaces sops-nix. `run_onchange_` scripts handle plugin installation triggers.

### Tool/Runtime Management: mise-en-place

**Why mise over alternatives:**

| Criteria | mise | asdf | Manual scripts |
|----------|------|------|----------------|
| Multi-ecosystem support | 17+ backends (ubi, pipx, cargo, etc.) | Plugin-based | N/A |
| Offline mode | `offline=true`, `always_keep_download`, `mise lock` | Limited | N/A |
| Task runner | Built-in `[tasks]` | No | Makefile |
| Auto env vars (JAVA_HOME) | Yes (with `mise activate`) | Plugin-dependent | Manual |
| Speed | Fast (Rust binary) | Slow (shell scripts) | N/A |
| Lock files | `mise lock` — pins exact download URLs | No | N/A |

mise handles Tier 1 and Tier 2 tools. Its offline support (`mise lock` + `always_keep_download` + `offline=true`) directly addresses the restricted deployment requirement. The built-in task runner replaces custom Makefile/scripts.

### Shell Framework: Lightweight manual approach

No oh-my-zsh, zinit, or similar framework. Instead:
- chezmoi templates for `.zshrc` / `.bashrc`
- 3 Zsh plugins via git clone (managed by `run_onchange_` script):
  - `zsh-autosuggestions`
  - `zsh-syntax-highlighting`
  - `fzf-tab`
- Completions: `carapace` (1000+ tools) via mise + `fzf-tab`
- Prompt: `starship` via mise
- History: `atuin` via mise

**Justification**: Only 3 Zsh plugins are needed. A framework adds startup overhead for no benefit. chezmoi manages plugin installation via `run_onchange_` scripts that clone repos.

### Containerized Approach: Hybrid

- **Host-level**: Tier 1/2 daily-driver CLI tools via mise + chezmoi
- **Docker image**: Tier 3 C++ toolchain for restricted environments (pre-built, transferred via `docker save/load`)
- **Not full devcontainer**: CLI tools should be on host for startup speed and UX quality

### Secrets Management: chezmoi age encryption

chezmoi has native support for age/gpg encryption:
- `chezmoi add --encrypt secret-file` — encrypts with age key
- Encrypted files stored as `encrypted_*` in source dir
- Key stored separately from source (not committed)
- Replaces sops-nix entirely

## Tool Tier Classification

### Tier 1 — Standalone binaries (alias/PATH swap)
Install via `mise ubi` (universal binary installer), `mise pipx`, or `mise cargo`.
No config files needed. Toggle via shell alias that can be killed by `kill-switch.sh`.

Examples: bat, eza, fd, ripgrep, zoxide, duf, dust, procs, bottom, xh, gping, dog, jq, yq, lazygit, delta, gh, k9s, kubectl, helm

### Tier 2 — Binaries with config/data files
Install via mise. Config managed by chezmoi (templates where machine-specific).

Examples: starship, atuin, fzf, tmux, neovim, helix, carapace, direnv, git, zsh

### Tier 3 — Complex toolchains with internal path resolution
Prefer apt (simpler, no path issues). mise for JVM/Go/Node/Rust (mise manages full prefix).

Examples: GDB, GCC, clang, CMake, Valgrind, LLDB, JDK 17, Maven, Gradle, Go, Node, Rust, Python

### Tier 4 — Container/platform-managed only
System-level daemons, GUI apps, kernel modules. Documented as prerequisites.

Examples: Docker daemon, wireshark, CUDA toolkit, WSL utilities, Nerd Fonts

## Kill Switch Design

The alias override system is designed with a kill switch:
- All modern CLI replacements are gated behind `[[ -z "${DOTFILES_NO_ALIASES:-}" ]]`
- `scripts/kill-switch.sh` (sourceable): exports `DOTFILES_NO_ALIASES=1` and unaliases everything
- Enables rapid fallback when a tool misbehaves or in restricted contexts
- Persistent: add `export DOTFILES_NO_ALIASES=1` to `~/.zshrc.local`

## Offline Deployment Strategy

Three deployment scenarios:

### Scenario A: Restricted network, internet available via proxy
```bash
export HTTPS_PROXY=http://proxy:3128
./bootstrap.sh
```
mise and chezmoi work through proxies natively.

### Scenario B: Fully air-gapped machine (must pre-bundle)
From an internet-connected machine:
```bash
mise lock                              # Pin all download URLs + checksums
mise install                          # Download + install (cached by always_keep_download)
tar -czf mise-cache.tar.gz ~/.cache/mise
scp mise-cache.tar.gz user@target:~
```
On the air-gapped machine:
```bash
tar -xzf mise-cache.tar.gz -C ~
./bootstrap.sh --offline              # Sets MISE_OFFLINE=1; installs from cache
```

### Scenario C: Restricted admin (no root)
- mise installs everything to `~/.local/bin` — no root needed
- chezmoi operates entirely in `~/`
- apt dependencies need root; skip with `./bootstrap.sh --no-apt`

## Migration Strategy

### Phase 1 (Foundation — this issue #20)
Set up chezmoi + mise structure alongside Nix. Non-destructive.
- Create all config files and directory structure
- Define tool tiers and install methods
- Do NOT remove Nix files

### Phase 2 (Issues #21, #22, #25)
Migrate configurations one by one, testing each:
- Bootstrap script (#21)
- mise tool configuration (#22)
- Dotfile migration to chezmoi (#25)

### Phase 3 (Issues #23, #26–#32)
Platform-specific and advanced features:
- Tier 3 complex toolchains (#23)
- Shell framework setup (#26)
- Agent detection & smart aliases (#27)
- Credentials & secrets (#28)
- Offline/restricted deployment (#29)
- WSL-specific support (#30)
- DX features (#31)
- Claude Code & AI tooling (#32)

### Phase 4 (Issues #33, #34)
Quality gates and documentation:
- CI/CD testing on fresh Ubuntu (#33)
- Full documentation (#34)

### Phase 5 (Future)
Remove Nix dependency after all phases validated.

## Consequences

### Positive
- Deploys to any Ubuntu machine, with or without internet
- No Nix, no flake evaluation, no home-manager activation overhead
- Shell startup time improves significantly
- Simpler mental model: chezmoi = dotfiles, mise = tools
- Kill switch for alias system
- Native secret encryption via age

### Negative
- Loses Nix's purity guarantees (tool versions may drift without `mise lock`)
- apt-installed tools may differ between Ubuntu versions
- No atomic rollback (unlike Home Manager generations) — mitigated by chezmoi backup

### Neutral
- Go template syntax in chezmoi templates is different from Nix, but simpler
- mise lock file provides reproducibility, not purity

## References

- [chezmoi docs](https://chezmoi.io)
- [mise docs](https://mise.jdx.dev)
- Issue #20: Architecture & Design (this document's source)
- Dependency graph: see issue #20 comments
