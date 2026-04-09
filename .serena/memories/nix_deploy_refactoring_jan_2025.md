# Nix-Deploy Refactoring - January 2025

## Overview

Completed comprehensive refactoring of nix-deploy tool from automated SSH execution to manual user-controlled deployment workflow with Determinate Nix installer integration.

**Status:** ✅ Completed  
**Commit:** 433cde8 on `completion_fix` branch  
**Date:** January 2025  
**Files Changed:** 8 files in nix-deploy/ (+1,259, -1,162 lines)

## Key Architectural Changes

### From: Automated 5-Phase Workflow
1. Build (local)
2. Package (local)
3. Transfer (SSH)
4. **Remote Installation (automated via SSH)** ❌
5. **Validation (automated via SSH)** ❌

### To: Manual 4-Phase Workflow
1. Build (local)
2. Package (local)
3. Transfer (SSH) + Generate INSTRUCTIONS.md
4. **Manual Deployment (user executes on remote)** ✅

## Core Implementations

### 1. Determinate Nix Installer Integration

**File:** `lib/packager.sh`

**Function Added:** `download_determinate_installer()`
- Downloads from: `https://install.determinate.systems/nix`
- Cache location: `~/.config/nix-deploy/cache/nix-installer.sh`
- Cache TTL: 7 days
- Fallback: curl → wget
- Auto-refresh stale cache

**Benefits:**
- Official Determinate Systems installer
- Smaller size (~60MB vs generic tarball)
- Better WSL support
- Active maintenance

### 2. Online/Offline Installation Script

**File:** `nix-deploy/remote/install-nix.sh`

**Complete rewrite** from 275 lines to 188 lines with 4 phases:

**Phase 1: Online Installation**
```bash
curl -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

**Phase 2: Offline Fallback**
```bash
bash ./nix-installer.sh install --no-confirm
```

**Phase 3: Configuration**
- Detect multi-user vs single-user
- Add offline-friendly settings (require-sigs = false, sandbox = false)
- Handle both `/etc/nix/nix.conf` and `~/.config/nix/nix.conf`

**Phase 4: Verification**
- Source Nix environment
- Verify `nix --version`
- Display installation method (online/offline)

**WSL-Specific Handling:**
- Detect WSL via `/proc/version`
- Pre-create `/nix` directory with proper ownership
- Avoid permission errors common in WSL

### 3. Manual Deployment Instructions

**File:** `lib/transfer.sh`

**Function Added:** `generate_instructions()`
- Creates `INSTRUCTIONS.md` on remote at `/tmp/nix-deploy/`
- Includes deployment summary (profile, closure size, timestamp)
- Step-by-step guide for all 5 scripts
- Comprehensive troubleshooting section
- Getting help resources

**Functions Removed:**
- `execute_remote_installation()` - 80 lines of SSH automation
- `validate_deployment()` - 35 lines of remote validation
- `rollback_deployment()` - 45 lines of automated rollback

**New User Experience:**
```bash
# After nix-deploy --target server completes:
ssh user@server
cd /tmp/nix-deploy
cat INSTRUCTIONS.md

# Execute step-by-step:
bash ./install-nix.sh
bash ./import-closure.sh
bash ./activate-profile.sh
bash ./setup-shell.sh  # optional
bash ./validate.sh     # optional
```

### 4. Main Orchestrator Updates

**File:** `bin/nix-deploy`

**Changes:**
- Removed Phase 4 (Remote Installation)
- Removed Phase 5 (Validation)
- Updated `show_post_deployment_info()` to show manual steps
- Modified `--rollback` to display manual rollback commands instead of executing

**Rollback Now Manual:**
```bash
ssh user@remote
home-manager switch --rollback
# Or: nix-env --switch-generation <number>
```

### 5. Configuration Cleanup

**File:** `lib/config.sh`

**Removed 12 Obsolete Options:**

From `defaults`:
- `nix_install_type: "single-user"` - Installer handles this
- `backup_existing: true` - Not automated
- `post_deploy_validation: true` - Not automated

From `deployment.nix`:
- `install_type: "single-user"` - User chooses during install
- `version: "2.18.1"` - Installer manages versions
- `offline_installer: true` - Always included now

From `deployment.options`:
- `activate_profile: true` - Manual execution
- `setup_shell_integration: true` - Manual execution
- `post_deploy_validation: true` - Manual execution
- `cleanup_temp_files: true` - User decides
- `backup_existing_profile: true` - Not automated
- `backup_path: "/path"` - Not used

**Kept Essential Options:**
- `deployment.nix.install_if_missing` - Controls installer download
- `deployment.paths.*` - Still needed for paths
- `deployment.wsl.*` - Platform-specific settings
- `deployment.ssh.*` - Transfer configuration
- `deployment.transfer.*` - Compression settings

## Documentation Updates

### README.md Changes

**Features Section:**
- Added: "Manual Control: User inspects and executes deployment steps"
- Added: "Online/Offline Installer: Determinate Nix with automatic fallback"
- Added: "Comprehensive Instructions: Step-by-step deployment guide on remote"
- Removed: "Backup & Rollback" (now manual)

**Workflow Section:**
- Rewrote Phase 4 from "Remote Installation" to "Manual Deployment (You Execute on Remote)"
- Added detailed manual execution steps with script names
- Updated Phase 3 to include instruction generation

**Configuration Examples:**
- Simplified target config (removed obsolete options)
- Updated global config (removed automated settings)

**Troubleshooting:**
- Changed "Remote Installation Issues" to "Remote Deployment Issues"
- Added manual re-execution guidance
- Updated to reference INSTRUCTIONS.md

**FAQ:**
- Updated Nix installer answer (Determinate with fallback)
- Added: "Why manual execution instead of automated deployment?"

### example-usage.md Changes

**Quick Setup:**
- Split "First Deployment" into "Transfer Package" (Step 3) and "Manual Deployment" (Step 4)
- Added detailed script execution steps
- Added verification and cleanup (Step 5)

**Scenarios:**
- Updated rollback to show manual commands
- Rewrote "Manual Steps" to reflect all deployments are now manual
- Simplified all target configuration examples

## Benefits Achieved

### 1. Security & Control
- ✅ No automated SSH command execution
- ✅ User reviews each script before running
- ✅ No surprise changes on remote systems
- ✅ Full visibility into deployment process

### 2. Troubleshooting
- ✅ Can pause between steps
- ✅ Easier to debug issues
- ✅ Can retry individual steps
- ✅ Clear error isolation

### 3. Flexibility
- ✅ Inspect and modify scripts if needed
- ✅ Skip optional steps (shell setup, validation)
- ✅ Customize installation parameters
- ✅ Better for restricted environments

### 4. Official Tooling
- ✅ Determinate Nix installer (maintained)
- ✅ Online installation preferred (faster, fresher)
- ✅ Offline fallback guaranteed
- ✅ WSL-specific improvements

## Remote File Structure

After `nix-deploy --target server` completes:

```
/tmp/nix-deploy/
├── INSTRUCTIONS.md           # Generated deployment guide
├── closure.nar.zst           # Compressed Nix store closure
├── metadata.json             # Deployment metadata
├── nix-installer.sh          # Cached Determinate installer
├── install-nix.sh            # Installation script (4-phase)
├── import-closure.sh         # Closure import script
├── activate-profile.sh       # Profile activation script
├── setup-shell.sh            # Shell integration (optional)
└── validate.sh               # Validation script (optional)
```

## Technical Details

### Installer Caching Logic
```bash
# Check if cached installer exists and is recent (< 7 days old)
file_age=$(($(date +%s) - $(stat -c %Y "$cached_installer")))
max_age=$((7 * 24 * 60 * 60))  # 7 days in seconds

if [[ $file_age -lt $max_age ]]; then
    log_info "Using cached installer (age: $((file_age / 86400)) days)"
else
    log_info "Cached installer is stale, downloading fresh copy"
fi
```

### Online/Offline Fallback Pattern
```bash
# Phase 1: Try online
if curl -L https://install.determinate.systems/nix | sh -s -- install $ARGS; then
    ONLINE_SUCCESS=true
fi

# Phase 2: Fall back to offline if online failed
if ! $ONLINE_SUCCESS; then
    bash "$OFFLINE_INSTALLER" install $ARGS
fi
```

### Instruction Generation
```bash
# Read metadata for personalized instructions
profile=$(jq -r '.profile // "unknown"' metadata.json)
closure_size=$(jq -r '.package.size // "unknown"' metadata.json)

# Generate instructions with dynamic values
ssh $ssh_opts "$remote" "cat > $remote_temp/INSTRUCTIONS.md" <<< "$instructions"
```

## Migration Notes

### Breaking Changes
- `--rollback` flag no longer executes rollback (displays manual commands instead)
- No automated validation after deployment
- Users must SSH to remote and execute scripts manually

### Backward Compatibility
- All configuration files still valid (obsolete options ignored)
- Package format unchanged
- Transfer mechanism unchanged
- Existing deployments can be rolled back manually

### User Impact
- **First deployment:** Requires reading INSTRUCTIONS.md and executing scripts
- **Updates:** Same manual process for consistency
- **Rollback:** Manual via `home-manager switch --rollback`
- **Learning curve:** Minimal, instructions are comprehensive

## Testing Recommendations

1. **WSL Deployment:**
   - Test /nix directory creation
   - Verify online installation
   - Test offline fallback (disconnect network)
   - Check WSL-specific workarounds

2. **Corporate Firewall:**
   - Verify offline installer works
   - Test with no internet access
   - Confirm instruction generation
   - Validate all scripts execute properly

3. **Multiple Profiles:**
   - Deploy different profiles to same machine
   - Verify profile switching
   - Test manual rollback

4. **Error Scenarios:**
   - Failed online installation
   - Missing offline installer
   - Interrupted closure import
   - Profile activation errors

## Future Enhancements (Not Implemented)

These were identified but marked as optional polish:

1. **Enhanced Remote Scripts:**
   - Better progress indicators
   - More detailed error messages
   - Consistent formatting across all scripts

2. **Config Validation:**
   - Could further validate removed options
   - Warning for deprecated settings

3. **Advanced Caching:**
   - Configurable cache TTL
   - Multiple installer versions
   - Automatic cleanup

## Related Files Modified in Same Session

The nix-deploy refactoring was committed separately (433cde8) from other changes (3aa559e):

**Other changes in "Completion fix 1" commit:**
- CUDA CLI implementation
- Serena configuration setup
- Module refactoring
- Script cleanup

These were intentionally separated to maintain clean git history.

## Commands to Review This Work

```bash
# View the nix-deploy commit
git show 433cde8

# See file changes
git diff 1da1c0e..433cde8 nix-deploy/

# Review documentation updates
git diff 1da1c0e..433cde8 -- nix-deploy/README.md nix-deploy/example-usage.md
```

## Lessons Learned

1. **Manual > Automated for Restricted Environments:**
   - Users prefer control over convenience in corporate settings
   - Inspection capability is a feature, not a limitation

2. **Official Tooling Wins:**
   - Determinate Nix installer better than generic solution
   - Active maintenance reduces long-term technical debt

3. **Documentation is Critical:**
   - INSTRUCTIONS.md makes manual process accessible
   - Step-by-step guides reduce user confusion

4. **Configuration Minimalism:**
   - Removing 12 obsolete options simplified maintenance
   - Less configuration = less confusion

5. **Separation of Concerns:**
   - Automated: What can be done locally (build, package, transfer)
   - Manual: What requires user judgment (install, activate, validate)
