#!/usr/bin/env bash
#
# utils.sh - Utility functions for nix-deploy
#

# Temporary directory for deployment
TEMP_DIR="${TEMP_DIR:-/tmp/nix-deploy-$$}"
CACHE_DIR="${NIX_DEPLOY_CACHE_DIR:-$HOME/.cache/nix-deploy}"

# Logging
LOG_FILE="${LOG_FILE:-$CONFIG_DIR/logs/deploy-$(date +%Y%m%d-%H%M%S).log}"

# Create necessary directories
init_directories() {
    mkdir -p "$CONFIG_DIR"/{targets,profiles,logs,cache,state}
    mkdir -p "$CACHE_DIR"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        ERROR)
            print_error "$message"
            ;;
        WARN)
            print_warn "$message"
            ;;
        INFO)
            if $VERBOSE; then
                print_info "$message"
            fi
            ;;
        DEBUG)
            print_debug "$message"
            ;;
    esac
}

log_error() { log ERROR "$@"; }
log_warn() { log WARN "$@"; }
log_info() { log INFO "$@"; }
log_debug() { log DEBUG "$@"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Require command or exit
require_command() {
    local cmd="$1"
    local message="${2:-$cmd is required but not found. Please install it.}"

    if ! command_exists "$cmd"; then
        print_error "$message"
        exit 1
    fi
}

# Check required commands
check_requirements() {
    local missing=()

    # Required commands
    local required=(nix nix-store nix-env ssh rsync zstd jq yq)

    for cmd in "${required[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing[*]}"
        print_info "Please install missing commands and try again"
        exit 1
    fi
}

# Get file size in human readable format
human_size() {
    local size="$1"
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0

    while (( size > 1024 && unit < 4 )); do
        size=$((size / 1024))
        unit=$((unit + 1))
    done

    echo "$size ${units[$unit]}"
}

# Calculate checksum
calculate_checksum() {
    local file="$1"
    local algorithm="${2:-sha256}"

    case "$algorithm" in
        sha256)
            sha256sum "$file" | awk '{print $1}'
            ;;
        sha512)
            sha512sum "$file" | awk '{print $1}'
            ;;
        md5)
            md5sum "$file" | awk '{print $1}'
            ;;
        *)
            log_error "Unknown checksum algorithm: $algorithm"
            return 1
            ;;
    esac
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local algorithm="${3:-sha256}"

    local actual
    actual=$(calculate_checksum "$file" "$algorithm")

    if [[ "$actual" != "$expected" ]]; then
        log_error "Checksum mismatch for $file"
        log_error "Expected: $expected"
        log_error "Actual:   $actual"
        return 1
    fi

    return 0
}

# Create backup
create_backup() {
    local source="$1"
    local backup_dir="${2:-$CONFIG_DIR/backups}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="$(basename "$source")-$timestamp"

    mkdir -p "$backup_dir"

    if [[ -d "$source" ]]; then
        tar -czf "$backup_dir/$backup_name.tar.gz" -C "$(dirname "$source")" "$(basename "$source")"
    else
        cp "$source" "$backup_dir/$backup_name"
    fi

    echo "$backup_dir/$backup_name"
}

# Save deployment state for resume
save_deployment_state() {
    local state_file="$CONFIG_DIR/state/deployment-$TARGET.json"
    mkdir -p "$(dirname "$state_file")"

    cat > "$state_file" << EOF
{
    "target": "$TARGET",
    "timestamp": "$(date -Iseconds)",
    "profile": "${PROFILE:-null}",
    "flake_ref": "${FLAKE_REF:-null}",
    "build_result": "${build_result:-null}",
    "package_path": "${package_path:-null}",
    "phase": "${CURRENT_PHASE:-build}",
    "temp_dir": "$TEMP_DIR"
}
EOF

    log_info "Deployment state saved to $state_file"
}

# Load deployment state for resume
load_deployment_state() {
    local state_file="$CONFIG_DIR/state/deployment-$TARGET.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "No deployment state found for target: $TARGET"
        return 1
    fi

    # Parse state file
    export RESUME_PROFILE=$(jq -r '.profile // empty' "$state_file")
    export RESUME_FLAKE_REF=$(jq -r '.flake_ref // empty' "$state_file")
    export RESUME_BUILD_RESULT=$(jq -r '.build_result // empty' "$state_file")
    export RESUME_PACKAGE_PATH=$(jq -r '.package_path // empty' "$state_file")
    export RESUME_PHASE=$(jq -r '.phase // "build"' "$state_file")
    export RESUME_TEMP_DIR=$(jq -r '.temp_dir // empty' "$state_file")

    # Use resumed values
    PROFILE="${PROFILE:-$RESUME_PROFILE}"
    FLAKE_REF="${FLAKE_REF:-$RESUME_FLAKE_REF}"
    TEMP_DIR="${RESUME_TEMP_DIR:-$TEMP_DIR}"

    log_info "Resumed deployment from phase: $RESUME_PHASE"
    return 0
}

# Clean deployment state
clean_deployment_state() {
    local state_file="$CONFIG_DIR/state/deployment-$TARGET.json"

    if [[ -f "$state_file" ]]; then
        rm "$state_file"
        log_info "Deployment state cleaned"
    fi
}

# Prompt for user input
prompt() {
    local prompt="$1"
    local default="${2:-}"
    local response

    if [[ -n "$default" ]]; then
        echo -n "$prompt [$default]: "
    else
        echo -n "$prompt: "
    fi

    read -r response
    echo "${response:-$default}"
}

# Prompt for password (hidden input)
prompt_password() {
    local prompt="$1"
    local password

    echo -n "$prompt: "
    read -rs password
    echo
    echo "$password"
}

# Prompt for yes/no
prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"

    local yn_prompt="[y/N]"
    if [[ "$default" =~ ^[Yy] ]]; then
        yn_prompt="[Y/n]"
    fi

    echo -n "$prompt $yn_prompt "
    read -r response

    response="${response:-$default}"
    [[ "$response" =~ ^[Yy] ]]
}

# Multi-select menu
select_option() {
    local prompt="$1"
    shift
    local options=("$@")

    echo "$prompt"
    select opt in "${options[@]}"; do
        if [[ -n "$opt" ]]; then
            echo "$opt"
            return 0
        fi
    done
}

# Progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local width=50

    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %3d%%" "$percent"

    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Spinner for long operations
spinner() {
    local pid="$1"
    local message="${2:-Processing...}"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        printf "\r%s %s" "${spinner[i]}" "$message"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.1
    done

    printf "\r%s Done!       \n" "$message"
}

# Wait for process with timeout
wait_with_timeout() {
    local pid="$1"
    local timeout="$2"
    local message="${3:-Waiting...}"

    local elapsed=0
    while kill -0 "$pid" 2>/dev/null && [[ $elapsed -lt $timeout ]]; do
        sleep 1
        elapsed=$((elapsed + 1))

        if (( elapsed % 10 == 0 )); then
            log_debug "$message ($elapsed/$timeout seconds)"
        fi
    done

    if kill -0 "$pid" 2>/dev/null; then
        log_warn "Process $pid did not complete within $timeout seconds"
        return 1
    fi

    return 0
}

# Retry command with exponential backoff
retry_with_backoff() {
    local max_attempts="${1:-5}"
    local delay="${2:-1}"
    shift 2
    local command=("$@")

    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if "${command[@]}"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_info "Attempt $attempt failed. Retrying in $delay seconds..."
            sleep "$delay"
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    log_error "Command failed after $max_attempts attempts: ${command[*]}"
    return 1
}

# Cleanup handler
cleanup_on_exit() {
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with code $exit_code"

        # Save state if in the middle of deployment
        if [[ -n "${TARGET:-}" ]] && [[ -n "${CURRENT_PHASE:-}" ]]; then
            save_deployment_state
        fi
    fi

    # Clean temporary directory if not resumable
    if [[ -d "$TEMP_DIR" ]] && [[ "$TEMP_DIR" == /tmp/nix-deploy-* ]]; then
        log_debug "Cleaning temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# Export functions
export -f log log_error log_warn log_info log_debug
export -f command_exists require_command check_requirements
export -f human_size calculate_checksum verify_checksum
export -f create_backup save_deployment_state load_deployment_state
export -f prompt prompt_password prompt_yes_no select_option
export -f show_progress spinner wait_with_timeout retry_with_backoff

# Initialize
init_directories