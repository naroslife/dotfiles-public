"""Safe subprocess execution utilities."""

import os
import subprocess
from pathlib import Path
from typing import List, Optional, Tuple


class SubprocessError(Exception):
    """Exception raised when subprocess execution fails."""

    def __init__(self, message: str, returncode: Optional[int] = None) -> None:
        """Initialize SubprocessError.

        Args:
            message: Error message describing the failure.
            returncode: Process return code if available.
        """
        super().__init__(message)
        self.returncode = returncode


def run_command(
    command: List[str],
    timeout: Optional[int] = None,
    check: bool = False,
    capture_output: bool = True,
) -> Tuple[int, str, str]:
    """Run a command safely and return result.

    Args:
        command: Command and arguments as list of strings.
        timeout: Timeout in seconds (None for no timeout).
        check: If True, raise SubprocessError on non-zero exit.
        capture_output: If True, capture stdout and stderr.

    Returns:
        Tuple of (returncode, stdout, stderr).

    Raises:
        SubprocessError: If command fails and check=True.
        subprocess.TimeoutExpired: If command times out.
    """
    try:
        result = subprocess.run(
            command,
            timeout=timeout,
            capture_output=capture_output,
            text=True,
            check=False,
        )

        if check and result.returncode != 0:
            raise SubprocessError(
                f"Command failed with exit code {result.returncode}: {' '.join(command)}",
                returncode=result.returncode,
            )

        return result.returncode, result.stdout, result.stderr

    except subprocess.TimeoutExpired as e:
        raise SubprocessError(
            f"Command timed out after {timeout} seconds: {' '.join(command)}"
        ) from e
    except FileNotFoundError as e:
        raise SubprocessError(f"Command not found: {command[0]}") from e


def check_command_exists(command: str) -> bool:
    """Check if a command exists in PATH.

    Args:
        command: Command name to check.

    Returns:
        True if command exists, False otherwise.
    """
    try:
        result = subprocess.run(
            ["which", command],
            capture_output=True,
            text=True,
            check=False,
        )
        return result.returncode == 0
    except Exception:
        return False


def check_file_executable(path: Path) -> bool:
    """Check if a file exists and is executable.

    Args:
        path: Path to file to check.

    Returns:
        True if file exists and is executable, False otherwise.
    """
    return path.exists() and path.is_file() and os.access(path, os.X_OK)


def validate_path_safe(path: Path, allowed_parent: Optional[Path] = None) -> bool:
    """Validate that a path is safe (no traversal attacks).

    Args:
        path: Path to validate.
        allowed_parent: If provided, ensure path is within this directory.

    Returns:
        True if path is safe, False otherwise.
    """
    try:
        resolved = path.resolve()
        if allowed_parent:
            return resolved.is_relative_to(allowed_parent.resolve())
        return True
    except (ValueError, RuntimeError):
        return False
