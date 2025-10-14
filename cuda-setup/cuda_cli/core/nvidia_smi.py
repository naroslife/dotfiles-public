"""nvidia-smi management and segfault fixing.

Handles nvidia-smi segfault issues on WSL2 by creating symlinks to Windows version.
"""

import os
from datetime import datetime
from pathlib import Path
from typing import Optional, Tuple

from ..utils.subprocess_utils import run_command, SubprocessError, validate_path_safe
from .constants import (
    WSL_NVIDIA_SMI_PATH,
    WINDOWS_NVIDIA_SMI_PATH,
    NVIDIA_SMI_TIMEOUT,
)


class NvidiaSmiError(Exception):
    """Exception raised for nvidia-smi related errors."""

    pass


def test_nvidia_smi(nvidia_smi_path: Optional[Path] = None) -> bool:
    """Test if nvidia-smi executes successfully.

    Args:
        nvidia_smi_path: Path to nvidia-smi binary. If None, uses system nvidia-smi.

    Returns:
        True if nvidia-smi runs successfully, False otherwise.
    """
    command = [str(nvidia_smi_path)] if nvidia_smi_path else ["nvidia-smi"]

    try:
        returncode, _, _ = run_command(
            command,
            timeout=NVIDIA_SMI_TIMEOUT,
            check=False,
            capture_output=True,
        )
        return returncode == 0
    except (SubprocessError, Exception):
        return False


def is_nvidia_smi_symlink() -> bool:
    """Check if WSL nvidia-smi is a symlink.

    Returns:
        True if nvidia-smi is a symlink, False otherwise.
    """
    return WSL_NVIDIA_SMI_PATH.is_symlink()


def get_nvidia_smi_target() -> Optional[Path]:
    """Get the target of nvidia-smi symlink if it exists.

    Returns:
        Path to symlink target or None if not a symlink.
    """
    if is_nvidia_smi_symlink():
        try:
            return WSL_NVIDIA_SMI_PATH.resolve()
        except (OSError, RuntimeError):
            return None
    return None


def backup_nvidia_smi() -> Optional[Path]:
    """Backup the current nvidia-smi binary.

    Creates a timestamped backup of the WSL nvidia-smi binary.

    Returns:
        Path to backup file or None if backup failed.
    """
    if not WSL_NVIDIA_SMI_PATH.exists() or is_nvidia_smi_symlink():
        return None

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = WSL_NVIDIA_SMI_PATH.parent / f"{WSL_NVIDIA_SMI_PATH.name}.old.{timestamp}"

    # Validate backup path is safe (within same directory)
    if not validate_path_safe(backup_path, WSL_NVIDIA_SMI_PATH.parent):
        raise NvidiaSmiError("Invalid backup path")

    try:
        returncode, _, stderr = run_command(
            ["sudo", "mv", str(WSL_NVIDIA_SMI_PATH), str(backup_path)],
            timeout=5,
            check=False,
        )
        if returncode == 0:
            return backup_path
        else:
            raise NvidiaSmiError(f"Failed to backup nvidia-smi: {stderr}")
    except SubprocessError as e:
        raise NvidiaSmiError(f"Failed to backup nvidia-smi: {e}")


def create_nvidia_smi_symlink() -> bool:
    """Create symlink from WSL nvidia-smi to Windows version.

    Returns:
        True if symlink created successfully, False otherwise.

    Raises:
        NvidiaSmiError: If Windows nvidia-smi doesn't exist or symlink creation fails.
    """
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        raise NvidiaSmiError(
            f"Windows nvidia-smi not found at {WINDOWS_NVIDIA_SMI_PATH}. "
            "Please install NVIDIA drivers on Windows first."
        )

    # Ensure parent directory exists
    parent_dir = WSL_NVIDIA_SMI_PATH.parent
    if not parent_dir.exists():
        try:
            returncode, _, stderr = run_command(
                ["sudo", "mkdir", "-p", str(parent_dir)],
                timeout=5,
                check=False,
            )
            if returncode != 0:
                raise NvidiaSmiError(f"Failed to create directory {parent_dir}: {stderr}")
        except SubprocessError as e:
            raise NvidiaSmiError(f"Failed to create directory {parent_dir}: {e}")

    # Create symlink
    try:
        returncode, _, stderr = run_command(
            ["sudo", "ln", "-sf", str(WINDOWS_NVIDIA_SMI_PATH), str(WSL_NVIDIA_SMI_PATH)],
            timeout=5,
            check=False,
        )
        if returncode != 0:
            raise NvidiaSmiError(f"Failed to create symlink: {stderr}")
        return True
    except SubprocessError as e:
        raise NvidiaSmiError(f"Failed to create symlink: {e}")


def fix_nvidia_smi(verbose: bool = False) -> Tuple[bool, str]:
    """Fix nvidia-smi segfault by creating symlink to Windows version.

    This function is idempotent - safe to run multiple times.

    Args:
        verbose: If True, return detailed messages.

    Returns:
        Tuple of (success, message) where success indicates if nvidia-smi is working
        and message provides details about what was done.

    Raises:
        NvidiaSmiError: If fix cannot be applied.
    """
    # Check if Windows nvidia-smi exists
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        raise NvidiaSmiError(
            "Windows nvidia-smi not found. Please install NVIDIA drivers on Windows first."
        )

    # If nvidia-smi is already a symlink, test if it works
    if is_nvidia_smi_symlink():
        target = get_nvidia_smi_target()
        if test_nvidia_smi():
            return True, f"nvidia-smi already working (symlink to {target})"
        else:
            # Symlink exists but not working, remove it
            try:
                run_command(["sudo", "rm", str(WSL_NVIDIA_SMI_PATH)], timeout=5, check=True)
            except SubprocessError as e:
                raise NvidiaSmiError(f"Failed to remove broken symlink: {e}")

    # If nvidia-smi is a regular file, test if it works
    if WSL_NVIDIA_SMI_PATH.exists() and not is_nvidia_smi_symlink():
        if test_nvidia_smi(WSL_NVIDIA_SMI_PATH):
            return True, "nvidia-smi already working, no fix needed"

        # nvidia-smi exists but segfaults, back it up
        backup_path = backup_nvidia_smi()
        message_parts = [f"Backed up old nvidia-smi to {backup_path}"]
    else:
        message_parts = []

    # Create symlink
    create_nvidia_smi_symlink()
    message_parts.append(f"Created symlink to {WINDOWS_NVIDIA_SMI_PATH}")

    # Verify the fix worked
    if test_nvidia_smi():
        message_parts.append("nvidia-smi is now working")
        return True, "; ".join(message_parts)
    else:
        return False, "Symlink created but nvidia-smi still not working"
