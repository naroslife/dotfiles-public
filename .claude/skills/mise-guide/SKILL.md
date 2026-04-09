---
name: mise-guide
description: "Use for anything related to mise, development tool versions, or dev environment setup. Triggers: (1) User mentions mise, mise.toml, .tool-versions, or mise commands like 'mise use', 'mise install', 'mise run'. (2) User wants to install, switch, pin, upgrade, or check versions of dev tools — node, python, go, ruby, java, rust, etc. — at project or global level, even without mentioning mise (e.g. 'set up node 22', 'what python version', 'upgrade go', 'check for outdated tools', 'configure dev environment'). (3) User wants to manage per-project environment variables via config files (e.g. 'add DATABASE_URL env var', 'set up env vars for different environments'). (4) User wants to define or run project tasks via mise (e.g. 'create a build task', 'run tests with mise'). Do NOT trigger for: Dockerfiles, package.json scripts, Makefiles, nvm/pyenv/rbenv commands, pip/npm package installation, git tags, CI/CD config, or deployment."
---

# mise — Dev Environment Manager

mise is a polyglot tool that replaces asdf/nvm/pyenv/direnv/make. It manages three things:

1. **Tool versions** — install and pin node, python, go, ruby, java, etc.
2. **Environment variables** — per-project env var management
3. **Tasks** — project task runner (like make/npm scripts)

## How to use this skill

Identify which domain the user needs, then read **only** the relevant reference file:

| User wants to... | Read |
|---|---|
| Install, switch, list, or manage tool versions | `references/tools.md` |
| Set, manage, or inspect environment variables | `references/env.md` |
| Define, run, or manage project tasks | `references/tasks.md` |

If the request spans multiple domains, read the relevant reference files.

## Key principles

1. **Always clarify scope.** When the user asks to install or use a tool, confirm whether they mean project-level (`mise use <tool>`) or global (`mise use -g <tool>`) before running commands. Project-level writes to `./mise.toml`; global writes to `~/.config/mise/config.toml`.

2. **Prefer `mise use` over `mise install`.** `mise use` both installs and pins the version in the config file. `mise install` only installs without pinning — it's mainly for pre-caching.

3. **Use `mise.toml` format.** This is mise's native config format and supports all features. `.tool-versions` is asdf-compatible but limited to tool versions only.

4. **Check before acting.** Run `mise ls` or `mise config ls` first to understand the current state before making changes.

5. **Verify mise is available.** Before running any mise command, run `which mise` to check availability. If not found, install it:
   ```bash
   curl https://mise.run | sh
   ```
   Then verify with `mise --version` before proceeding.
