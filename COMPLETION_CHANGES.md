# Completion-Related Changes (Working → Broken)

## Critical Changes

**533c775 - modules/shells/bash.nix**
- Removed: `complete -D -F _lazy_load_carapace` (lazy-loading)
- Added: `source <(carapace _carapace bash)` (immediate loading)
- Added: Agent detection functions + `export -f cat ls ll la grep find`
- Impact: Carapace loads in wrong context, exported functions shadow commands

**533c775 - modules/shells/default.nix**
- Disabled: `programs.fzf = shellHelpers.enableWithShells defaultShells;`
- Impact: FZF integration removed, fzf-tab and tool pickers broken

**e015a5e - modules/shells/default.nix (Atuin)**
- Changed: `search_mode = "fuzzy"` → `"skim"`
- Changed: `filter_mode = "host"` → `"global"`
- Changed: `style = "compact"` → `"full"`
- Changed: `inline_height = 10` → `20`
- Impact: Different readline input handling, more aggressive history

## Secondary Changes

**658e7b8 - modules/shells/zsh.nix**
- Added: 6 new keybinding variations (Home/End, Ctrl+Arrow)
- Impact: Possible readline spillover to bash

**050fa6c, 3662853, 780f2fe - scripts/**
- Added: dotfiles-git-helper.sh, dotfiles-docker-helper.sh, dotfiles-nix-helper.sh
- Impact: Depend on FZF but FZF integration disabled

**scripts/functions/navigation.sh**
- Functions: `fcd()`, `f()`, `fv()` call FZF directly
- Impact: Sourced at startup, FZF not integrated

**scripts/functions/smart-reminders.sh**
- Overrides: `cd`, `ls`, `find`, `ps` with wrappers
- Impact: Double function wrapping with agent-detection

**45c9812, 6697b7c, 8974dbd - bash.nix**
- Added: `enableCompletion = false`, `BASH_COMPLETION_VERSINFO=999`
- Impact: Block bash-completion (later reverted)

## Root Cause

**Working:** Lazy-load carapace + FZF enabled + Atuin fuzzy mode
**Broken:** Immediate carapace + FZF disabled + Atuin skim mode + exported functions

## Current State Issues

1. FZF still disabled (not restored)
2. Atuin still in skim/global/full mode
3. Function sourcing conflicts remain
4. Initialization order problems

## Fixes Needed

1. Re-enable: `programs.fzf = shellHelpers.enableWithShells defaultShells;`
2. Revert Atuin: fuzzy/host/compact/10
3. Check smart-reminders.sh conflicts

---

## Current File State (HEAD at 16afaae)

### modules/shells/bash.nix
**Line 25-26:** FZF config exported but FZF may not be integrated
```bash
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow'
```

**Line 33-41:** Carapace lazy-loading (CORRECT - reverted back)
```bash
_lazy_load_carapace() {
  if command -v carapace >/dev/null 2>&1; then
    source <(carapace _carapace)
    unset -f _lazy_load_carapace
  fi
}
complete -F _lazy_load_carapace -D
```

**Line 48-55:** ALL scripts/functions/*.sh sourced at startup
```bash
for func_file in "$HOME/dotfiles-public/scripts/functions"/*.sh; do
  if [ -f "$func_file" ]; then
    source "$func_file"
  fi
done
```
- **Impact:** Loads smart-reminders.sh, navigation.sh, history-tools.sh, nix-sudo.sh
- **Risk:** Multiple function overrides (cd, ls, find) before completion loads

**Line 63-101:** Package manager helper functions
- Functions: npm-clean, pip-clean, cargo-clean, venv
- **Impact:** Additional functions in global namespace during completion

### modules/shells/default.nix
**Line 194:** FZF IS NOW ENABLED (was previously disabled)
```nix
programs.fzf = shellHelpers.enableWithShells defaultShells;
```
- **Status:** ✅ FIXED - FZF integration restored

**Line 100-192:** Atuin configuration (STILL IN SKIM MODE)
```nix
search_mode = "skim";           # Line 109 - WAS "fuzzy"
filter_mode = "global";         # Line 110 - WAS "host"
style = "full";                 # Line 112 - WAS "compact"
inline_height = 20;             # Line 113 - WAS 10
```
- **Impact:** Skim mode has different readline/input handling than fuzzy
- **Risk:** May interfere with completion context or CTRL+C handling

**Line 158-183:** Atuin common_subcommands list
- Includes: git, npm, cargo, nix, home-manager, docker, kubectl, etc.
- **Impact:** Atuin may intercept subcommand completion for these

### modules/shells/zsh.nix
**Line 68-78:** Multiple keybinding variations
```bash
bindkey "^[[H" beginning-of-line      # Home (standard)
bindkey "^[[1~" beginning-of-line     # Home (alternate)
bindkey "^[[F" end-of-line            # End (standard)
bindkey "^[[4~" end-of-line           # End (alternate)
bindkey "^[[1;5C" forward-word        # Ctrl+Right (standard)
bindkey "^[[1;5D" backward-word       # Ctrl+Left (standard)
bindkey "^[^[[C" forward-word         # Ctrl+Right (alternate)
bindkey "^[^[[D" backward-word        # Ctrl+Left (alternate)
```
- **Note:** ZSH-specific, shouldn't affect bash
- **Risk:** Low, but Home Manager might apply cross-shell

**Line 87-104:** fzf-tab configuration (requires FZF)
```bash
zstyle ':fzf-tab:complete:cd:*' fzf-preview '/home/uif58593/.nix-profile/bin/eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
zstyle ':fzf-tab:*' continuous-trigger '/'
```
- **Impact:** Now works since FZF is re-enabled

**Line 106-109:** Carapace immediate loading in ZSH
```bash
if command -v carapace >/dev/null 2>&1; then
  source <(carapace _carapace zsh)
fi
```
- **Note:** ZSH uses immediate loading, not lazy

### modules/shells/readline.nix
**Line 32-34:** Tab completion binding
```inputrc
"\\t" = "menu-complete";
"\\e[Z" = "menu-complete-backward";
```
- **Impact:** Tab does menu-complete, not standard complete
- **Risk:** May conflict with carapace's completion expectations

**Line 37-41:** CTRL bindings
```inputrc
"\\C-l" = "clear-screen";
"\\C-w" = "backward-kill-word";
"\\C-u" = "unix-line-discard";
```
- **Note:** No CTRL+C handler defined

**Line 76:** Bracketed paste mode
```inputrc
enable-bracketed-paste = true;
```
- **Impact:** May affect how paste/CTRL+C interact

### scripts/functions/smart-reminders.sh
**Line 40:** sed -i (can be interrupted by CTRL+C)
```bash
sed -i "s/^$cmd=.*/$cmd=$((current_count + 1))/" "$counter_file" 2>/dev/null
```
- **Risk:** If CTRL+C during sed, could leave .command_counter corrupt

**Line 44-75:** Command overrides
```bash
cd() { show_reminder "cd" "br" ...; __zoxide_z "$@"; }
find() { show_reminder "find" "fd" ...; command find "$@"; }
ls() { show_reminder "ls" "eza" ...; command ls "$@"; }
```
- **Impact:** Overrides cd, find, ls that carapace may complete
- **Risk:** Function context during completion

### scripts/functions/navigation.sh
**Line 8, 11, 14:** Direct FZF calls
```bash
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }
f() { find . -type f -not -path '*/.*' | fzf | xclip -selection clipboard; }
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)"; }
```
- **Impact:** FZF now available since programs.fzf enabled
- **Risk:** If FZF interrupted by CTRL+C in completion context

## Probable Issues

### 1. Atuin Skim Mode + Readline Interaction
- **File:** modules/shells/default.nix:109
- **Issue:** Skim mode may hook into readline differently than fuzzy
- **Test:** Revert to `search_mode = "fuzzy"`

### 2. Tab = menu-complete
- **File:** modules/shells/readline.nix:33
- **Issue:** Non-standard completion behavior
- **Test:** Change to standard `complete` or `possible-completions`

### 3. Function Sourcing Order
- **File:** modules/shells/bash.nix:48-55
- **Issue:** smart-reminders.sh loads AFTER carapace lazy-load setup
- **Test:** Source functions BEFORE setting up carapace

### 4. sed -i Interruption
- **File:** scripts/functions/smart-reminders.sh:40
- **Issue:** CTRL+C during sed could cause issues
- **Test:** Wrap in trap or use atomic write
