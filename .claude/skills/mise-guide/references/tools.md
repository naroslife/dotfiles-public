# Tool Version Management with mise

## Workflow

### 1. Check current state

```bash
mise ls                    # list installed tools and active versions
mise config ls             # list loaded config files and their precedence
mise current               # show currently active tool versions
```

### 2. Search and discover tools

```bash
mise search <query>        # search available tools by name
mise ls-remote <tool>      # list all available versions for a tool
mise latest <tool>         # show latest stable version
mise outdated              # check which installed tools have newer versions
```

### 3. Install and pin tools

**Project-level** (writes to `./mise.toml` in current directory):
```bash
mise use node@22           # install and pin node 22 (latest 22.x)
mise use python@3.12       # install and pin python 3.12
mise use node@22 go@1.22   # install multiple tools at once
```

**Global** (writes to `~/.config/mise/config.toml`):
```bash
mise use -g node@22        # install and pin globally
mise use -g python@3.12
```

### 4. Version specifiers

| Specifier | Meaning | Example |
|---|---|---|
| `22` | Latest matching major | `node@22` -> 22.x.x |
| `22.1` | Latest matching minor | `node@22.1` -> 22.1.x |
| `22.1.0` | Exact version | `node@22.1.0` |
| `latest` | Latest stable | `node@latest` |
| `lts` | Latest LTS | `node@lts` |
| `prefix:1.19` | Latest with prefix | `go@prefix:1.19` |

### 5. Multiple versions

Python example — install two versions, first one is the default:
```toml
# mise.toml
[tools]
python = ["3.12", "3.11"]
```

### 6. Other useful commands

```bash
mise install               # install all tools from config (no pinning)
mise install node@22       # install specific version without pinning
mise uninstall node@22     # remove an installed version
mise unuse node            # remove tool from current config
mise upgrade               # upgrade tools to latest compatible versions
mise prune                 # remove unused tool versions to free space
mise which node            # show path to the active node binary
mise where node@22         # show installation directory
mise exec node@20 -- node -v  # run command with specific version
mise shell node@20         # activate version for current shell session only
mise reshim                # rebuild shim binaries (if using shims)
```

### 7. Config file format

```toml
# mise.toml
[tools]
node = "22"
python = "3.12"
go = "1.22"
ruby = "3.3"

# with options
node = { version = "22", postinstall = "corepack enable" }

# from package managers
"npm:typescript" = "latest"
"npm:@anthropic-ai/claude-code" = "latest"
```

### 8. Package backends

Install tools from different ecosystems:

```bash
mise use "aqua:BurntSushi/ripgrep"     # from aqua registry (PREFERRED for CLI tools)
mise use "github:sharkdp/bat"          # from GitHub releases (fallback if not in aqua)
mise use "npm:typescript"              # from npm
mise use "pipx:black"                  # from pip/pipx
mise use "cargo:ripgrep"               # from cargo
```

**Backend priority for CLI tools:**
1. **`aqua:`** — preferred. Registry compiled into mise, checksummed, cross-platform. Check: `mise registry | grep aqua:`
2. **`github:`** — fallback for tools not in aqua registry. Downloads from GitHub releases.
3. **`ubi:`** — **DEPRECATED**. Migrate to `aqua:` or `github:`. Replace `ubi:owner/repo` with `aqua:owner/repo` or `github:owner/repo`.

```toml
# mise.toml — preferred format
[tools]
"aqua:sharkdp/bat" = "latest"         # aqua registry (best)
"github:theryangeary/choose" = "latest"  # GitHub releases (if not in aqua)
"pipx:visidata" = "latest"            # Python tools
"cargo:rustscan" = "latest"           # Rust tools
```

## Language-specific notes

### Node.js
- Reads `.nvmrc` / `.node-version` files (when enabled)
- Default npm packages: add to `~/.default-npm-packages`
- Enable corepack: `node = { version = "22", postinstall = "corepack enable" }`

### Python
- Downloads precompiled binaries by default (fast install)
- Virtual environment support in config
- Compile from source: `mise settings python.compile=1`
- Default packages: `~/.default-python-packages`

### Java
- Auto-sets `JAVA_HOME` with `mise activate` (not with shims alone)
- Multiple distributions: temurin, corretto, zulu, etc.

### Go
- For Go <=1.20, use prefix syntax: `go@prefix:1.20`
- Default packages: `~/.default-go-packages`

## Troubleshooting

```bash
mise doctor                # diagnose setup issues
mise config ls             # check config file precedence
mise settings ls           # show all settings
mise self-update           # update mise itself
```
