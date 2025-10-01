#!/bin/bash

# Read Claude Code context from stdin
input=$(cat)

# Extract information from the JSON input
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')

# Get current time
current_time=$(date +%H:%M)

# Get git info if in a git repository
git_info=""
if git rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    if [ -n "$branch" ]; then
        # Get git status indicators
        git_status=""
        if ! git diff --quiet 2>/dev/null; then
            git_status="${git_status}*"
        fi
        if ! git diff --cached --quiet 2>/dev/null; then
            git_status="${git_status}+"
        fi
        if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
            git_status="${git_status}?"
        fi
        
        git_info=" ${branch}${git_status}"
    fi
fi

# Simplify directory path (similar to Starship truncation)
display_dir="$current_dir"
if [ "$current_dir" != "$project_dir" ] && [ -n "$project_dir" ]; then
    # Show relative path from project root if possible
    rel_path=${current_dir#$project_dir}
    if [ "$rel_path" != "$current_dir" ]; then
        display_dir="$(basename "$project_dir")${rel_path}"
    fi
fi

# Truncate long paths
if [ ${#display_dir} -gt 30 ]; then
    display_dir="…/${display_dir##*/}"
fi

# Build the status line with colors (using printf for color codes)
printf "\033[2m\033[38;2;163;174;210m░▒▓\033[0m"
printf "\033[2m\033[48;2;163;174;210m\033[38;2;9;12;12m  \033[0m"
printf "\033[2m\033[48;2;118;159;240m\033[38;2;163;174;210m\033[0m"
printf "\033[2m\033[48;2;118;159;240m\033[38;2;227;229;229m %s \033[0m" "$display_dir"
printf "\033[2m\033[38;2;118;159;240m\033[48;2;57;66;96m\033[0m"
if [ -n "$git_info" ]; then
    printf "\033[2m\033[48;2;57;66;96m\033[38;2;118;159;240m %s \033[0m" "$git_info"
fi
printf "\033[2m\033[38;2;57;66;96m\033[48;2;33;39;54m\033[0m"
printf "\033[2m\033[48;2;29;34;48m\033[38;2;163;174;210m  %s \033[0m" "$current_time"
printf "\033[2m\033[38;2;29;34;48m \033[0m"
printf "\033[2m%s\033[0m" "$model_name"