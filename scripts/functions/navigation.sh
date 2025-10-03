#!/usr/bin/env bash
# Navigation and file management functions

# Change directory and list contents
cx() { cd "$@" && l; }

# Fuzzy find and change to directory
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && l; }

# Find file and copy path to clipboard
f() { find . -type f -not -path '*/.*' | fzf | xclip -selection clipboard; }

# Fuzzy find and edit file
fv() { nvim "$(find . -type f -not -path '*/.*' | fzf)"; }

# Ranger function with cd integration
function ranger {
  local IFS=$'\t\n'
  local tempfile
  tempfile="$(mktemp -t tmp.XXXXXX)"
  local ranger_cmd=(
    command
    ranger
    --cmd="map Q chain shell echo %d > \"$tempfile\"; quitall"
  )

  "${ranger_cmd[@]}" "$@"
  if [[ -f "$tempfile" ]] && [[ "$(cat -- "$tempfile")" != "$(pwd)" ]]; then
    cd -- "$(cat "$tempfile")" || return
  fi
  command rm -f -- "$tempfile" 2>/dev/null
}