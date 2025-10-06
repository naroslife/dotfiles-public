#!/usr/bin/env bash
#
# import-closure.sh - Import Nix closure on remote machine
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# Check if Nix is available
if ! command -v nix-store >/dev/null 2>&1; then
    echo_error "Nix is not installed or not in PATH"
    echo_info "Please source Nix environment: source ~/.nix-profile/etc/profile.d/nix.sh"
    exit 1
fi

# Find closure NAR file
CLOSURE_NAR=""
if [[ -f "closure.nar.zst" ]]; then
    CLOSURE_NAR="closure.nar.zst"
    echo_info "Found compressed closure: $CLOSURE_NAR"
elif [[ -f "closure.nar.gz" ]]; then
    CLOSURE_NAR="closure.nar.gz"
    echo_info "Found compressed closure: $CLOSURE_NAR"
elif [[ -f "closure.nar" ]]; then
    CLOSURE_NAR="closure.nar"
    echo_info "Found uncompressed closure: $CLOSURE_NAR"
else
    echo_error "No closure NAR file found"
    exit 1
fi

# Decompress if needed
if [[ "$CLOSURE_NAR" == *.zst ]]; then
    echo_info "Decompressing with zstd..."
    if command -v zstd >/dev/null 2>&1; then
        zstd -d "$CLOSURE_NAR" -o closure.nar
    else
        echo_error "zstd not found. Please install: apt-get install zstd"
        exit 1
    fi
    CLOSURE_NAR="closure.nar"
elif [[ "$CLOSURE_NAR" == *.gz ]]; then
    echo_info "Decompressing with gzip..."
    gunzip -c "$CLOSURE_NAR" > closure.nar
    CLOSURE_NAR="closure.nar"
fi

# Import closure
echo_info "Importing Nix closure..."
echo_info "This may take a while for large closures..."

# Count store paths being imported (if closure.list exists)
if [[ -f "closure.list" ]]; then
    NUM_PATHS=$(wc -l < closure.list)
    echo_info "Importing $NUM_PATHS store paths"
fi

# Import with progress if pv is available
if command -v pv >/dev/null 2>&1 && [[ -f "$CLOSURE_NAR" ]]; then
    SIZE=$(stat -c%s "$CLOSURE_NAR")
    pv -s "$SIZE" "$CLOSURE_NAR" | nix-store --import
else
    nix-store --import < "$CLOSURE_NAR"
fi

if [[ $? -eq 0 ]]; then
    echo_info "Closure imported successfully"
else
    echo_error "Failed to import closure"
    exit 1
fi

# Read metadata to get the activation package path
if [[ -f "metadata.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
        STORE_PATH=$(jq -r '.store_path' metadata.json)
        echo_info "Activation package: $STORE_PATH"

        # Save for activate-profile.sh
        echo "$STORE_PATH" > activation-package.path
    else
        echo_warn "jq not found, cannot parse metadata"
        echo_info "You'll need to manually find the activation package in /nix/store"
    fi
fi

# Verify imported paths
echo_info "Verifying imported store paths..."
if [[ -f "closure.list" ]]; then
    MISSING_PATHS=0
    while IFS= read -r path; do
        if [[ ! -e "$path" ]]; then
            echo_warn "Missing: $path"
            MISSING_PATHS=$((MISSING_PATHS + 1))
        fi
    done < closure.list

    if [[ $MISSING_PATHS -eq 0 ]]; then
        echo_info "All store paths imported successfully"
    else
        echo_warn "$MISSING_PATHS store paths are missing"
    fi
fi

# Clean up decompressed NAR if we created it
if [[ -f "closure.nar" ]] && [[ -f "closure.nar.zst" || -f "closure.nar.gz" ]]; then
    echo_info "Cleaning up decompressed NAR..."
    rm -f closure.nar
fi

echo_info "Import complete!"