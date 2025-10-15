#!/usr/bin/env bash
# Smart update checker for dotfiles
# Checks for updates, caches results, and provides actionable information

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Constants
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
readonly CACHE_FILE="$CACHE_DIR/last-update-check"
readonly CACHE_EXPIRY_SECONDS=$((24 * 60 * 60))  # 24 hours
readonly DEFAULT_REMOTE="origin"
readonly DEFAULT_BRANCH="main"

# Options
FORCE_CHECK=false
AUTO_PULL=false
VERBOSE=false
QUIET=false

# Create cache directory
mkdir -p "$CACHE_DIR"

# Parse command line options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE_CHECK=true
                shift
                ;;
            -p|--pull)
                AUTO_PULL=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                export LOG_LEVEL=$LOG_LEVEL_DEBUG
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Smart update checker for dotfiles repository.
Checks for updates from remote, caches results, and provides actionable information.

Options:
  -f, --force     Force check, bypassing cache
  -p, --pull      Automatically pull updates if available
  -v, --verbose   Show detailed commit information
  -q, --quiet     Suppress all output unless updates are available
  -h, --help      Show this help message

Cache:
  Results are cached in: $CACHE_FILE
  Cache expires after: 24 hours

Examples:
  $(basename "$0")              # Check for updates (uses cache)
  $(basename "$0") --force      # Force fresh check
  $(basename "$0") --pull       # Check and auto-pull if updates available
  $(basename "$0") --verbose    # Show detailed commit messages

EOF
}

# Check if cache is valid
is_cache_valid() {
    if [[ ! -f "$CACHE_FILE" ]] || $FORCE_CHECK; then
        return 1
    fi

    local cache_age
    local current_time
    local cache_time

    current_time=$(date +%s)
    cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    cache_age=$((current_time - cache_time))

    if [[ $cache_age -lt $CACHE_EXPIRY_SECONDS ]]; then
        log_debug "Cache is valid (age: $((cache_age / 3600)) hours)"
        return 0
    else
        log_debug "Cache expired (age: $((cache_age / 3600)) hours)"
        return 1
    fi
}

# Get git repository info
get_repo_info() {
    local repo_dir="${1:-$ROOT_DIR}"

    # Check if it's a git repository (could be a worktree with .git file)
    if [[ ! -d "$repo_dir/.git" ]] && [[ ! -f "$repo_dir/.git" ]]; then
        die "Not a git repository: $repo_dir" 2 "Run from dotfiles directory"
    fi

    cd "$repo_dir" || die "Cannot change to repository directory: $repo_dir"

    # Get current branch
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || current_branch="unknown"

    # Get remote tracking branch
    local tracking_branch
    tracking_branch=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) || tracking_branch=""

    # Extract remote name and branch from tracking
    local remote_name="$DEFAULT_REMOTE"
    local remote_branch="$DEFAULT_BRANCH"

    if [[ -n "$tracking_branch" ]]; then
        remote_name="${tracking_branch%%/*}"
        remote_branch="${tracking_branch#*/}"
    fi

    echo "$current_branch|$remote_name|$remote_branch"
}

# Fetch updates from remote
fetch_updates() {
    local remote_name="$1"

    log_debug "Fetching updates from $remote_name..."

    if ! git fetch "$remote_name" --quiet 2>/dev/null; then
        if ! $QUIET; then
            log_warn "Failed to fetch from remote '$remote_name'"
            log_info "Check network connection: curl -I https://github.com"
        fi
        return 1
    fi

    return 0
}

# Check for available updates
check_updates() {
    local remote_name="$1"
    local remote_branch="$2"
    local current_branch="$3"

    # Compare local and remote
    local local_commit
    local remote_commit
    local behind_count
    local ahead_count

    local_commit=$(git rev-parse HEAD 2>/dev/null) || return 1
    remote_commit=$(git rev-parse "$remote_name/$remote_branch" 2>/dev/null) || return 1

    # Check if we're behind or ahead
    behind_count=$(git rev-list --count "HEAD..$remote_name/$remote_branch" 2>/dev/null) || behind_count=0
    ahead_count=$(git rev-list --count "$remote_name/$remote_branch..HEAD" 2>/dev/null) || ahead_count=0

    log_debug "Local: $local_commit (first 7: ${local_commit:0:7})"
    log_debug "Remote: $remote_commit (first 7: ${remote_commit:0:7})"
    log_debug "Behind: $behind_count, Ahead: $ahead_count"

    echo "$behind_count|$ahead_count|$local_commit|$remote_commit"
}

# Get commit details
get_commit_details() {
    local remote_name="$1"
    local remote_branch="$2"
    local limit="${3:-10}"

    git log --oneline --no-decorate "HEAD..$remote_name/$remote_branch" --max-count="$limit" 2>/dev/null
}

# Format time ago
format_time_ago() {
    local timestamp="$1"
    local current_time
    local diff_seconds

    current_time=$(date +%s)
    diff_seconds=$((current_time - timestamp))

    if [[ $diff_seconds -lt 60 ]]; then
        echo "$diff_seconds seconds ago"
    elif [[ $diff_seconds -lt 3600 ]]; then
        echo "$((diff_seconds / 60)) minutes ago"
    elif [[ $diff_seconds -lt 86400 ]]; then
        echo "$((diff_seconds / 3600)) hours ago"
    else
        echo "$((diff_seconds / 86400)) days ago"
    fi
}

# Display update information
display_updates() {
    local behind_count="$1"
    local ahead_count="$2"
    local remote_name="$3"
    local remote_branch="$4"
    local last_check_time="${5:-}"

    # If quiet mode and no updates, don't display anything
    if $QUIET && [[ $behind_count -eq 0 ]]; then
        return
    fi

    if [[ $behind_count -gt 0 ]]; then
        echo -e "${COLOR_CYAN}📦 Dotfiles Update Available${COLOR_NC}"
        echo -e "   ${COLOR_YELLOW}$behind_count new commit$([ $behind_count -ne 1 ] && echo 's')${COLOR_NC} since last update"

        if [[ -n "$last_check_time" ]]; then
            echo -e "   Last checked: $(format_time_ago "$last_check_time")"
        fi

        echo

        if $VERBOSE || [[ $behind_count -le 5 ]]; then
            echo -e "${COLOR_CYAN}Recent changes:${COLOR_NC}"
            get_commit_details "$remote_name" "$remote_branch" "$behind_count" | while read -r line; do
                # Parse commit hash and message
                local hash="${line%% *}"
                local message="${line#* }"

                # Colorize based on conventional commit type
                case "$message" in
                    feat:*|feat\(*\):*)
                        echo -e "  ${COLOR_GREEN}•${COLOR_NC} $message"
                        ;;
                    fix:*|fix\(*\):*)
                        echo -e "  ${COLOR_YELLOW}•${COLOR_NC} $message"
                        ;;
                    docs:*|docs\(*\):*)
                        echo -e "  ${COLOR_BLUE}•${COLOR_NC} $message"
                        ;;
                    refactor:*|refactor\(*\):*|chore:*|chore\(*\):*)
                        echo -e "  ${COLOR_CYAN}•${COLOR_NC} $message"
                        ;;
                    *)
                        echo -e "  • $message"
                        ;;
                esac
            done
            echo
        fi

        echo -e "${COLOR_GREEN}Run:${COLOR_NC} dotfiles update --pull"
        echo -e "${COLOR_GREEN}Or:${COLOR_NC} cd $ROOT_DIR && git pull"

        if [[ $ahead_count -gt 0 ]]; then
            echo
            echo -e "${COLOR_YELLOW}⚠ Note:${COLOR_NC} You have $ahead_count local commit$([ $ahead_count -ne 1 ] && echo 's') not in remote"
            echo -e "  Consider pushing your changes or stashing them before pulling"
        fi
    else
        if ! $QUIET; then
            echo -e "${COLOR_GREEN}✓${COLOR_NC} Dotfiles are up to date"

            if [[ -n "$last_check_time" ]]; then
                echo -e "  Last checked: $(format_time_ago "$last_check_time")"
            fi

            if [[ $ahead_count -gt 0 ]]; then
                echo -e "  ${COLOR_CYAN}ℹ${COLOR_NC} You have $ahead_count unpushed commit$([ $ahead_count -ne 1 ] && echo 's')"
            fi
        fi
    fi
}

# Pull updates
pull_updates() {
    local remote_name="$1"
    local remote_branch="$2"

    echo -e "${COLOR_CYAN}Pulling updates from $remote_name/$remote_branch...${COLOR_NC}"

    if git pull "$remote_name" "$remote_branch"; then
        echo -e "${COLOR_GREEN}✓${COLOR_NC} Successfully updated dotfiles"
        echo
        echo "Next steps:"
        echo "  • Run: ./apply.sh           # Apply configuration changes"
        echo "  • Run: source ~/.bashrc      # Reload shell configuration"
        return 0
    else
        log_error "Failed to pull updates"
        echo
        echo "Troubleshooting:"
        echo "  • Check for uncommitted changes: git status"
        echo "  • Stash changes if needed: git stash"
        echo "  • Try manual pull: git pull $remote_name $remote_branch"
        return 1
    fi
}

# Save cache
save_cache() {
    local data="$1"
    local timestamp
    timestamp=$(date +%s)

    cat > "$CACHE_FILE" << EOF
timestamp=$timestamp
data=$data
EOF

    log_debug "Cache saved to $CACHE_FILE"
}

# Load cache
load_cache() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    # Source the cache file
    local timestamp=""
    local data=""

    # shellcheck source=/dev/null
    source "$CACHE_FILE" 2>/dev/null || return 1

    if [[ -z "$timestamp" ]] || [[ -z "$data" ]]; then
        return 1
    fi

    echo "$timestamp|$data"
}

# Main function
main() {
    parse_options "$@"

    # Change to repository directory
    cd "$ROOT_DIR" || die "Cannot change to repository directory: $ROOT_DIR"

    # Get repository information
    local repo_info current_branch remote_name remote_branch
    repo_info=$(get_repo_info "$ROOT_DIR")
    IFS='|' read -r current_branch remote_name remote_branch <<< "$repo_info"

    log_debug "Repository info: branch=$current_branch, remote=$remote_name/$remote_branch"

    local behind_count ahead_count local_commit remote_commit
    local last_check_time=""

    # Check cache first
    if is_cache_valid; then
        log_debug "Using cached results"

        local cache_data
        cache_data=$(load_cache)

        if [[ -n "$cache_data" ]]; then
            IFS='|' read -r last_check_time update_info <<< "$cache_data"
            IFS='|' read -r behind_count ahead_count local_commit remote_commit <<< "$update_info"

            # Verify that our local commit hasn't changed
            local current_local_commit
            current_local_commit=$(git rev-parse HEAD 2>/dev/null)

            if [[ "$current_local_commit" != "$local_commit" ]]; then
                log_debug "Local commit has changed, invalidating cache"
                FORCE_CHECK=true
            fi
        else
            FORCE_CHECK=true
        fi
    fi

    # Perform fresh check if needed
    if $FORCE_CHECK || [[ -z "$behind_count" ]]; then
        log_debug "Performing fresh update check"

        # Fetch updates
        if ! fetch_updates "$remote_name"; then
            if ! $QUIET; then
                log_warn "Could not fetch updates from remote"
            fi
            exit 1
        fi

        # Check for updates
        local update_info
        update_info=$(check_updates "$remote_name" "$remote_branch" "$current_branch")
        IFS='|' read -r behind_count ahead_count local_commit remote_commit <<< "$update_info"

        # Save to cache
        save_cache "$update_info"
        last_check_time=$(date +%s)
    fi

    # Display update information
    display_updates "$behind_count" "$ahead_count" "$remote_name" "$remote_branch" "$last_check_time"

    # Auto-pull if requested and updates available
    if $AUTO_PULL && [[ $behind_count -gt 0 ]]; then
        echo
        if [[ $ahead_count -gt 0 ]]; then
            log_warn "Cannot auto-pull: you have unpushed local commits"
            log_info "Resolve conflicts manually or stash your changes first"
            exit 1
        else
            pull_updates "$remote_name" "$remote_branch"
        fi
    fi

    # Exit code: 0 if up to date or successfully pulled, 1 if updates available
    if [[ $behind_count -gt 0 ]] && ! $AUTO_PULL; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"