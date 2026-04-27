#!/usr/bin/env bash
# Smart reminders for modern CLI tools

# Kill switch: if active, skip all overrides so system defaults apply
_KILL_SWITCH="${HOME}/.config/shell/use-system-defaults"
if [[ -f "${_KILL_SWITCH}" ]] || [[ -n "${DOTFILES_NO_ALIASES:-}" ]]; then
  unset _KILL_SWITCH
  return 0 2>/dev/null || exit 0
fi
unset _KILL_SWITCH

# is_agent fallback — defined here so this file works standalone (e.g. tests)
if ! declare -f is_agent >/dev/null 2>&1; then
  is_agent() {
    [[ -n "${CLAUDE:-}" ]] || [[ -n "${CODEX:-}" ]] || [[ -n "${COPILOT:-}" ]] || [[ -n "${AI_AGENT:-}" ]]
  }
fi

# Counter for tracking command usage
if [[ ! -f ~/.command_counter ]]; then
  {
    echo "cd=0"
    echo "find=0"
    echo "htop=0"
    echo "top=0"
    echo "ls=0"
    echo "du=0"
    echo "df=0"
    echo "ps=0"
    echo "ping=0"
    echo "dig=0"
    echo "git_diff=0"
    echo "man=0"
    echo "wc=0"
  } > ~/.command_counter
fi

# Function to show reminder and increment counter
show_reminder() {
  # Skip reminders in agent mode or when explicitly disabled
  if is_agent || [[ "${SMART_REMINDERS:-1}" == "0" ]]; then return 0; fi
  local cmd="$1"
  local alternative="$2"
  local description="$3"
  local counter_file=~/.command_counter
  local current_count
  current_count=$(grep "^$cmd=" "$counter_file" | cut -d= -f2 2>/dev/null || echo 0)

  # Show reminder every 5th usage
  if (( current_count % 5 == 4 )); then
    echo "💡 Reminder: Try '$alternative' instead of '$cmd' - $description"
  fi

  # Increment counter
  sed -i "s/^$cmd=.*/$cmd=$((current_count + 1))/" "$counter_file" 2>/dev/null || echo "$cmd=1" >> "$counter_file"
}

# Command overrides with smart reminders
# cd: use zoxide when available (silently in agent mode, with reminders interactively)
cd() {
  show_reminder "cd" "br" "interactive directory navigation with broot"
  if command -v __zoxide_z >/dev/null 2>&1; then
    __zoxide_z "$@"
  else
    builtin cd "$@" || return
  fi
}

find() {
  show_reminder "find" "fd" "faster and more user-friendly file finder"
  command find "$@"
}

htop() {
  show_reminder "htop" "btm" "modern system monitor with better visuals"
  command htop "$@"
}

top() {
  show_reminder "top" "btm" "modern system monitor with graphs and colors"
  command top "$@"
}

ls() {
  show_reminder "ls" "eza" "modern ls with colors, icons, and git integration"
  command ls "$@"
}

du() {
  show_reminder "du" "dust" "modern du with tree view and colors"
  command du "$@"
}

df() {
  show_reminder "df" "duf" "modern df with better formatting and colors"
  command df "$@"
}

ps() {
  show_reminder "ps" "procs" "modern ps with colors and search capabilities"
  command ps "$@"
}

ping() {
  show_reminder "ping" "gping" "ping with real-time graphs"
  command ping "$@"
}

dig() {
  show_reminder "dig" "dog" "modern dig with better output and DNS-over-HTTPS"
  command dig "$@"
}

man() {
  show_reminder "man" "tldr" "simplified and practical examples"
  command man "$@"
}

wc() {
  show_reminder "wc" "tokei" "fast code line counter with language detection"
  command wc "$@"
}

# Git improvements (only show occasionally, not aliased)
git() {
  if [[ "$1" == "diff" ]]; then
    show_reminder "git_diff" "git difftool" "use delta for syntax-highlighted diffs"
  fi
  command git "$@"
}
