#!/usr/bin/env bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CORP_TEST_IPS=("192.0.2.1" "192.0.2.2" "192.0.2.3")  # TEST-NET-1 (RFC 5737) - never routable
SOURCES_DIR="/etc/apt/sources.list.d"
DISABLED_DIR="$SOURCES_DIR/disabled"

# Function to test corporate network connectivity - FAST VERSION
test_corporate_network() {
    # Quick test: try to connect to first IP on port 443 (very fast)
    timeout 0.5 bash -c "echo >/dev/tcp/${CORP_TEST_IPS[0]}/443" &>/dev/null && return 0

    # If that fails, try a quick ping to any corporate IP
    for ip in "${CORP_TEST_IPS[@]}"; do
        timeout 0.2 ping -c 1 -W 1 "$ip" &>/dev/null && return 0
    done

    return 1
}

# Parse command line arguments
FORCE_MODE=""
QUIET_MODE=""
if [[ "$1" == "--force-corp" ]] || [[ "$1" == "-c" ]]; then
    FORCE_MODE="corp"
elif [[ "$1" == "--force-public" ]] || [[ "$1" == "-p" ]]; then
    FORCE_MODE="public"
elif [[ "$1" == "--quiet" ]] || [[ "$1" == "-q" ]]; then
    QUIET_MODE="1"
elif [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Usage: apt-network-switch [OPTIONS]"
    echo "  -c, --force-corp     Force corporate repositories"
    echo "  -p, --force-public   Force public repositories"
    echo "  -q, --quiet          Quiet mode (minimal output)"
    echo "  -h, --help          Show this help message"
    exit 0
fi

# Function for conditional output
log() {
    if [[ -z "$QUIET_MODE" ]]; then
        echo -e "$@"
    fi
}

if [[ -n "$FORCE_MODE" ]]; then
    log "${YELLOW}Forcing $FORCE_MODE mode...${NC}"
    if [[ "$FORCE_MODE" == "corp" ]]; then
        network_detected=0
    else
        network_detected=1
    fi
else
    log "${YELLOW}Quick network detection...${NC}"
    test_corporate_network
    network_detected=$?
fi

if [[ $network_detected -eq 0 ]]; then
    log "${GREEN}✓ Enterprise network detected${NC}"

    # Enable corporate sources
    if [ -d "$DISABLED_DIR" ] && [ "$(ls -A $DISABLED_DIR 2>/dev/null)" ]; then
        log "Enabling corporate repositories..."
        sudo mv $DISABLED_DIR/*.list $SOURCES_DIR/ 2>/dev/null
    fi

    # Clear public sources
    if [ -s /etc/apt/sources.list ]; then
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.public-backup
        echo "# Corporate network - using sources.list.d/*" | sudo tee /etc/apt/sources.list > /dev/null
    fi

    log "${GREEN}APT configured for corporate network${NC}"

else
    log "${YELLOW}✗ Home/Public network detected${NC}"

    # Disable corporate sources
    sudo mkdir -p "$DISABLED_DIR"
    if [ "$(ls -A $SOURCES_DIR/*.list 2>/dev/null)" ]; then
        log "Disabling corporate repositories..."
        sudo mv $SOURCES_DIR/*.list $DISABLED_DIR/ 2>/dev/null
    fi

    # Enable public Ubuntu sources
    if [ ! -s /etc/apt/sources.list ] || grep -q "using sources.list.d" /etc/apt/sources.list; then
        log "Enabling public Ubuntu repositories..."
        cat << 'SOURCES' | sudo tee /etc/apt/sources.list > /dev/null
# Ubuntu 22.04 (Jammy) repositories
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# Docker CE repository (public)
# deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable
SOURCES
    fi

    log "${GREEN}APT configured for public network${NC}"
fi

# Only run apt update if not in quiet mode
if [[ -z "$QUIET_MODE" ]]; then
    log "\n${YELLOW}Running apt update...${NC}"
    if sudo apt update; then
        log "\n${GREEN}✓ APT update successful!${NC}"
    else
        log "\n${RED}✗ APT update failed. Check your network connection.${NC}"
        exit 1
    fi
fi
