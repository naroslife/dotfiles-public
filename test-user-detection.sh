#!/usr/bin/env bash
# Test script for user detection in flake.nix

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing user detection in flake.nix${NC}"
echo

# Test 1: Known user (naroslife)
echo -e "${YELLOW}Test 1: Known user 'naroslife'${NC}"
export CURRENT_USER="naroslife"
export GIT_EMAIL=""
export GIT_NAME=""
nix eval --impure .#homeConfigurations.naroslife.config.programs.git.userEmail 2>&1 | grep -v warning || true
echo

# Test 2: Known user (enterpriseuser)
echo -e "${YELLOW}Test 2: Known user 'enterpriseuser'${NC}"
export CURRENT_USER="enterpriseuser"
nix eval --impure .#homeConfigurations.enterpriseuser.config.programs.git.userEmail 2>&1 | grep -v warning || true
echo

# Test 3: Dynamic user with git config
echo -e "${YELLOW}Test 3: Dynamic user 'uif58593' with git config${NC}"
export CURRENT_USER="uif58593"
export GIT_EMAIL="robi54321@gmail.com"
export GIT_NAME="naroslife"
nix eval --impure .#homeConfigurations.uif58593.config.programs.git.userEmail 2>&1 | grep -v warning || true
echo

# Test 4: List all available configurations
echo -e "${YELLOW}Test 4: List all available home configurations${NC}"
export CURRENT_USER="uif58593"
export GIT_EMAIL="robi54321@gmail.com"
export GIT_NAME="naroslife"
nix flake show 2>&1 | grep -A 5 "homeConfigurations" | grep -v warning || true
echo

echo -e "${GREEN}All tests completed!${NC}"
