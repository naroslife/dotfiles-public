"""NVIDIA driver detection and validation.

Handles driver version detection, comparison, and compatibility checking.
"""

import re
from typing import Optional, Tuple
from packaging import version

from ..utils.subprocess_utils import run_command, SubprocessError
from .constants import (
    WINDOWS_NVIDIA_SMI_PATH,
    MIN_WINDOWS_DRIVER,
    RECOMMENDED_DRIVER,
    CUDA_VERSION,
    NVIDIA_SMI_TIMEOUT,
)


class DriverError(Exception):
    """Exception raised for driver-related errors."""

    pass


def get_driver_version() -> Optional[str]:
    """Get Windows NVIDIA driver version.

    Returns:
        Driver version string (e.g., "566.03") or None if not found.

    Raises:
        DriverError: If nvidia-smi execution fails.
    """
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        return None

    try:
        returncode, stdout, stderr = run_command(
            [str(WINDOWS_NVIDIA_SMI_PATH)],
            timeout=NVIDIA_SMI_TIMEOUT,
            check=False,
            capture_output=True,
        )

        if returncode != 0:
            raise DriverError(f"nvidia-smi failed: {stderr}")

        # Parse driver version from output
        match = re.search(r"Driver Version:\s*([0-9.]+)", stdout)
        if match:
            return match.group(1)

        return None

    except SubprocessError as e:
        raise DriverError(f"Failed to get driver version: {e}")


def get_driver_cuda_version() -> Optional[str]:
    """Get CUDA version supported by the driver.

    Returns:
        CUDA version string (e.g., "12.4") or None if not found.

    Raises:
        DriverError: If nvidia-smi execution fails.
    """
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        return None

    try:
        returncode, stdout, stderr = run_command(
            [str(WINDOWS_NVIDIA_SMI_PATH)],
            timeout=NVIDIA_SMI_TIMEOUT,
            check=False,
            capture_output=True,
        )

        if returncode != 0:
            raise DriverError(f"nvidia-smi failed: {stderr}")

        # Parse CUDA version from output
        match = re.search(r"CUDA Version:\s*([0-9.]+)", stdout)
        if match:
            return match.group(1)

        return None

    except SubprocessError as e:
        raise DriverError(f"Failed to get CUDA version: {e}")


def get_gpu_name() -> Optional[str]:
    """Get GPU model name.

    Returns:
        GPU name string or None if not found.

    Raises:
        DriverError: If nvidia-smi execution fails.
    """
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        return None

    try:
        returncode, stdout, stderr = run_command(
            [
                str(WINDOWS_NVIDIA_SMI_PATH),
                "--query-gpu=name",
                "--format=csv,noheader",
            ],
            timeout=NVIDIA_SMI_TIMEOUT,
            check=False,
            capture_output=True,
        )

        if returncode != 0:
            raise DriverError(f"nvidia-smi failed: {stderr}")

        gpu_name = stdout.strip()
        return gpu_name if gpu_name else None

    except SubprocessError as e:
        raise DriverError(f"Failed to get GPU name: {e}")


def compare_versions(ver1: str, ver2: str) -> int:
    """Compare two version strings.

    Args:
        ver1: First version string (e.g., "566.03").
        ver2: Second version string (e.g., "528.33").

    Returns:
        -1 if ver1 < ver2, 0 if ver1 == ver2, 1 if ver1 > ver2.
    """
    v1 = version.parse(ver1)
    v2 = version.parse(ver2)

    if v1 < v2:
        return -1
    elif v1 > v2:
        return 1
    else:
        return 0


def version_meets_minimum(driver_version: str, minimum_version: str) -> bool:
    """Check if driver version meets minimum requirement.

    Args:
        driver_version: Current driver version string.
        minimum_version: Minimum required version string.

    Returns:
        True if driver version meets or exceeds minimum, False otherwise.
    """
    return compare_versions(driver_version, minimum_version) >= 0


def check_driver_compatibility() -> Tuple[bool, str, dict]:
    """Check if driver is compatible with CUDA 12.9.

    Returns:
        Tuple of (is_compatible, message, info_dict) where:
        - is_compatible: True if driver meets minimum requirements
        - message: Human-readable status message
        - info_dict: Dictionary with driver information

    Raises:
        DriverError: If driver information cannot be retrieved.
    """
    # Check if Windows nvidia-smi exists
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        return (
            False,
            "Windows NVIDIA driver not found",
            {
                "driver_version": None,
                "cuda_version": None,
                "gpu_name": None,
                "min_required": MIN_WINDOWS_DRIVER,
                "recommended": RECOMMENDED_DRIVER,
            },
        )

    # Get driver information
    driver_ver = get_driver_version()
    if not driver_ver:
        raise DriverError("Could not determine driver version")

    cuda_ver = get_driver_cuda_version()
    gpu_name = get_gpu_name()

    info_dict = {
        "driver_version": driver_ver,
        "cuda_version": cuda_ver,
        "gpu_name": gpu_name,
        "min_required": MIN_WINDOWS_DRIVER,
        "recommended": RECOMMENDED_DRIVER,
        "target_cuda": CUDA_VERSION,
    }

    # Check if driver meets minimum requirements
    if version_meets_minimum(driver_ver, MIN_WINDOWS_DRIVER):
        if version_meets_minimum(driver_ver, RECOMMENDED_DRIVER):
            message = f"Driver {driver_ver} is up-to-date and supports CUDA {CUDA_VERSION}"
        else:
            message = (
                f"Driver {driver_ver} supports CUDA {CUDA_VERSION}, "
                f"but {RECOMMENDED_DRIVER}+ recommended"
            )
        return True, message, info_dict
    else:
        message = (
            f"Driver {driver_ver} is too old. "
            f"Minimum {MIN_WINDOWS_DRIVER} required for CUDA {CUDA_VERSION}"
        )
        return False, message, info_dict
