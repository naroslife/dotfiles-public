#!/usr/bin/env bash
# Git Helper - Interactive git workflow with fzf
# Usage: dotfiles-git-helper.sh or dotfiles git

set -euo pipefail

# Script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/lib/common.sh"
elif [[ -f "$SCRIPT_DIR/../lib/common.sh" ]]; then
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/../lib/common.sh"
else
    echo "Error: Could not find common.sh" >&2
    exit 1
fi

# Check for required tools
require_command git "Install git: sudo apt install git (Ubuntu/Debian) or brew install git (macOS)"
require_command fzf "fzf should be installed via home-manager. Try: dotfiles apply"

# Git operations menu
show_git_menu() {
    local choice

    # Create menu with preview
    choice=$(cat << 'EOF' | fzf \
        --height=80% \
        --border=rounded \
        --header='Git Helper - Select an operation' \
        --preview='echo {}' \
        --preview-window=up:3:wrap \
        --prompt='Git > ' \
        --pointer='▶' \
        --marker='✓'
status          View repository status
diff            View changes (staged and unstaged)
diff-staged     View staged changes only
log             View commit history with graph
log-oneline     View compact commit history
commit          Stage and commit changes
commit-all      Stage all changes and commit
push            Push current branch to remote
pull            Pull from remote and rebase
fetch           Fetch from all remotes
branch          List and manage branches
checkout        Switch to another branch
merge           Merge a branch into current
rebase          Rebase current branch
stash-save      Stash current changes
stash-list      List all stashes
stash-pop       Apply and remove latest stash
stash-apply     Apply latest stash (keep in list)
clean           Clean untracked files (interactive)
reset-soft      Undo last commit (keep changes)
reset-hard      Reset to HEAD (DANGER: lose changes)
remote          Show remote repositories
tags            List all tags
blame           Show who changed each line in file
EOF
)

    # Handle the selected operation
    if [[ -z "$choice" ]]; then
        log_info "No operation selected"
        return 0
    fi

    local operation
    operation=$(echo "$choice" | awk '{print $1}')

    log_info "Executing: $operation"
    echo ""

    case "$operation" in
        status)
            git status
            ;;
        diff)
            git diff HEAD
            ;;
        diff-staged)
            git diff --cached
            ;;
        log)
            git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit -20
            ;;
        log-oneline)
            git log --oneline -20
            ;;
        commit)
            echo "Staging changes interactively..."
            git add -p
            echo ""
            read -p "Commit message: " -r msg
            if [[ -n "$msg" ]]; then
                git commit -m "$msg"
                log_info "Changes committed successfully"
            else
                log_warn "Commit cancelled - no message provided"
            fi
            ;;
        commit-all)
            echo "Staging all changes..."
            git add -A
            git status
            echo ""
            read -p "Commit message: " -r msg
            if [[ -n "$msg" ]]; then
                git commit -m "$msg"
                log_info "All changes committed successfully"
            else
                log_warn "Commit cancelled - no message provided"
            fi
            ;;
        push)
            local current_branch
            current_branch=$(git branch --show-current)
            log_info "Pushing $current_branch to remote..."
            git push origin "$current_branch"
            ;;
        pull)
            log_info "Pulling and rebasing from remote..."
            git pull --rebase
            ;;
        fetch)
            log_info "Fetching from all remotes..."
            git fetch --all --prune
            ;;
        branch)
            echo "=== Local Branches ==="
            git branch -vv
            echo ""
            echo "=== Remote Branches ==="
            git branch -r
            echo ""
            read -p "Create new branch? (leave empty to skip): " -r new_branch
            if [[ -n "$new_branch" ]]; then
                git checkout -b "$new_branch"
                log_info "Created and switched to branch: $new_branch"
            fi
            ;;
        checkout)
            local selected_branch
            selected_branch=$(git branch --all | sed 's/^[* ] //' | sed 's#remotes/origin/##' | sort -u | fzf --height=40% --prompt='Checkout branch > ')
            if [[ -n "$selected_branch" ]]; then
                git checkout "$selected_branch"
                log_info "Switched to branch: $selected_branch"
            fi
            ;;
        merge)
            local selected_branch
            selected_branch=$(git branch | sed 's/^[* ] //' | fzf --height=40% --prompt='Merge branch > ')
            if [[ -n "$selected_branch" ]]; then
                log_info "Merging $selected_branch into current branch..."
                git merge "$selected_branch"
            fi
            ;;
        rebase)
            local selected_branch
            selected_branch=$(git branch | sed 's/^[* ] //' | fzf --height=40% --prompt='Rebase onto > ')
            if [[ -n "$selected_branch" ]]; then
                log_info "Rebasing onto $selected_branch..."
                git rebase "$selected_branch"
            fi
            ;;
        stash-save)
            read -p "Stash message (optional): " -r msg
            if [[ -n "$msg" ]]; then
                git stash push -m "$msg"
            else
                git stash push
            fi
            log_info "Changes stashed"
            ;;
        stash-list)
            git stash list
            ;;
        stash-pop)
            git stash pop
            log_info "Latest stash applied and removed"
            ;;
        stash-apply)
            git stash apply
            log_info "Latest stash applied (still in stash list)"
            ;;
        clean)
            log_warn "This will remove untracked files"
            git clean -i
            ;;
        reset-soft)
            log_warn "This will undo the last commit but keep your changes"
            if ask_yes_no "Continue?"; then
                git reset --soft HEAD~1
                log_info "Last commit undone, changes still staged"
            fi
            ;;
        reset-hard)
            log_error "WARNING: This will PERMANENTLY DELETE all uncommitted changes!"
            if ask_yes_no "Are you absolutely sure?"; then
                git reset --hard HEAD
                log_info "Reset to HEAD"
            else
                log_info "Reset cancelled"
            fi
            ;;
        remote)
            git remote -v
            ;;
        tags)
            git tag -l
            ;;
        blame)
            # List files and let user select one
            local selected_file
            selected_file=$(git ls-files | fzf --height=40% --prompt='Blame file > ')
            if [[ -n "$selected_file" ]]; then
                git blame "$selected_file"
            fi
            ;;
        *)
            log_error "Unknown operation: $operation"
            return 1
            ;;
    esac

    echo ""
    log_info "Operation completed"
}

# Main entry point
main() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        die "Not in a git repository" 1 "Navigate to a git repository first"
    fi

    # Show the menu
    show_git_menu
}

# Run main
main "$@"
