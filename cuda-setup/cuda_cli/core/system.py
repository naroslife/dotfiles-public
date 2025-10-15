"""System detection and validation.

Detects WSL2 environment and validates system compatibility for CUDA setup.
"""

import os
import re
from pathlib import Path
from typing import Tuple

from .constants import WSL_INTEROP_PATHS, PROC_VERSION_PATH


def is_wsl2() -> bool:
    """Check if running on WSL2.

    Uses multiple detection methods:
    1. WSL_DISTRO_NAME environment variable
    2. WSLInterop files in /proc
    3. /proc/version kernel string

    Returns:
        True if running on WSL2, False otherwise.
    """
    # Check environment variable
    if os.environ.get("WSL_DISTRO_NAME"):
        return True

    # Check for WSLInterop files
    for interop_path in WSL_INTEROP_PATHS:
        if interop_path.exists():
            return True

    # Check /proc/version for WSL2 markers
    if PROC_VERSION_PATH.exists():
        try:
            version_content = PROC_VERSION_PATH.read_text()
            if re.search(r"(microsoft.*wsl2|wsl2)", version_content, re.IGNORECASE):
                return True
        except (OSError, PermissionError):
            pass

    return False


def get_wsl_distro_name() -> str:
    """Get the name of the current WSL2 distribution.

    Returns:
        Distribution name or "Unknown" if not available.
    """
    return os.environ.get("WSL_DISTRO_NAME", "Unknown")


def get_os_info() -> Tuple[str, str]:
    """Get OS distribution and version information.

    Returns:
        Tuple of (distribution_name, version) or ("Unknown", "Unknown") on error.
    """
    try:
        # Try to read /etc/os-release
        os_release_path = Path("/etc/os-release")
        if os_release_path.exists():
            content = os_release_path.read_text()

            name_match = re.search(r'^NAME="?([^"\n]+)"?', content, re.MULTILINE)
            version_match = re.search(r'^VERSION="?([^"\n]+)"?', content, re.MULTILINE)

            name = name_match.group(1) if name_match else "Unknown"
            version = version_match.group(1) if version_match else "Unknown"

            return name, version
    except (OSError, PermissionError):
        pass

    return "Unknown", "Unknown"


def get_kernel_version() -> str:
    """Get Linux kernel version.

    Returns:
        Kernel version string or "Unknown" on error.
    """
    if PROC_VERSION_PATH.exists():
        try:
            version_content = PROC_VERSION_PATH.read_text()
            # Extract version number (e.g., "5.15.90.1-microsoft-standard-WSL2")
            match = re.search(r"Linux version ([^\s]+)", version_content)
            if match:
                return match.group(1)
        except (OSError, PermissionError):
            pass

    return "Unknown"
