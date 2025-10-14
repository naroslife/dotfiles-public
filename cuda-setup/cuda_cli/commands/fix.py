"""Fix command - Fix nvidia-smi segfault issue."""

import typer

from ..core.system import is_wsl2
from ..core.nvidia_smi import (
    fix_nvidia_smi,
    test_nvidia_smi,
    is_nvidia_smi_symlink,
    get_nvidia_smi_target,
    NvidiaSmiError,
)
from ..core.constants import WSL_NVIDIA_SMI_PATH, WINDOWS_NVIDIA_SMI_PATH
from ..utils.output import (
    console,
    print_info,
    print_success,
    print_error,
    print_warning,
    print_header,
    print_json_output,
)


def fix(
    json_output: bool = typer.Option(
        False,
        "--json",
        help="Output results as JSON",
    ),
    verbose: bool = typer.Option(
        False,
        "--verbose",
        "-v",
        help="Show detailed information",
    ),
) -> None:
    """Fix nvidia-smi segfault by creating symlink to Windows version.

    This command fixes the common nvidia-smi segfault issue on WSL2 by
    replacing the broken WSL nvidia-smi with a symlink to the working
    Windows version.

    The fix is idempotent - safe to run multiple times.
    """
    # Check WSL2
    if not is_wsl2():
        if json_output:
            print_json_output({"error": "Not running on WSL2", "success": False})
        else:
            print_error("This tool is designed for WSL2 environments")
        raise typer.Exit(1)

    if not json_output:
        print_header("Fix nvidia-smi Segfault")

    # Check current status
    if verbose and not json_output:
        print_info("Checking current nvidia-smi status...")

        if WSL_NVIDIA_SMI_PATH.exists():
            if is_nvidia_smi_symlink():
                target = get_nvidia_smi_target()
                console.print(f"  nvidia-smi is a symlink to: {target}")
            else:
                console.print(f"  nvidia-smi is a regular file at: {WSL_NVIDIA_SMI_PATH}")
        else:
            console.print(f"  nvidia-smi does not exist at: {WSL_NVIDIA_SMI_PATH}")

        console.print()

    # Verify Windows nvidia-smi exists
    if not WINDOWS_NVIDIA_SMI_PATH.exists():
        error_msg = "Windows nvidia-smi not found. Please install NVIDIA drivers on Windows first."
        if json_output:
            print_json_output({"error": error_msg, "success": False})
        else:
            print_error(error_msg)
            console.print()
            print_info("Download drivers from: https://www.nvidia.com/Download/index.aspx")
        raise typer.Exit(1)

    # Apply fix
    if not json_output:
        print_info("Applying nvidia-smi fix...")

    try:
        success, message = fix_nvidia_smi(verbose=verbose)

        if json_output:
            print_json_output({
                "success": success,
                "message": message,
                "wsl_nvidia_smi": str(WSL_NVIDIA_SMI_PATH),
                "windows_nvidia_smi": str(WINDOWS_NVIDIA_SMI_PATH),
            })
        else:
            console.print()
            if success:
                print_success("nvidia-smi fix applied successfully!")
                if verbose:
                    console.print(f"  {message}")
            else:
                print_warning("Fix applied but nvidia-smi may still have issues")
                console.print(f"  {message}")

            # Test nvidia-smi output
            console.print()
            print_info("Testing nvidia-smi output:")
            console.print()

            if test_nvidia_smi():
                # Try to show GPU info
                from ..core.driver import get_gpu_name, get_driver_version, get_driver_cuda_version

                try:
                    gpu_name = get_gpu_name()
                    driver_ver = get_driver_version()
                    cuda_ver = get_driver_cuda_version()

                    if gpu_name:
                        console.print(f"  GPU: [cyan]{gpu_name}[/cyan]")
                    if driver_ver:
                        console.print(f"  Driver: [cyan]{driver_ver}[/cyan]")
                    if cuda_ver:
                        console.print(f"  CUDA Version: [cyan]{cuda_ver}[/cyan]")
                except Exception as e:
                    if verbose:
                        print_warning(f"Could not get full GPU info: {e}")
                    console.print("  nvidia-smi is working (details unavailable)")
            else:
                print_error("nvidia-smi test failed")
                console.print()
                print_info("Manual fix steps:")
                console.print(f"  sudo mv {WSL_NVIDIA_SMI_PATH} {WSL_NVIDIA_SMI_PATH}.old")
                console.print(
                    f"  sudo ln -s {WINDOWS_NVIDIA_SMI_PATH} {WSL_NVIDIA_SMI_PATH}"
                )
                raise typer.Exit(1)

            console.print()

    except NvidiaSmiError as e:
        if json_output:
            print_json_output({"error": str(e), "success": False})
        else:
            print_error(f"Failed to fix nvidia-smi: {e}")
            console.print()
            print_info("Manual fix steps:")
            console.print(f"  sudo mv {WSL_NVIDIA_SMI_PATH} {WSL_NVIDIA_SMI_PATH}.old")
            console.print(f"  sudo ln -s {WINDOWS_NVIDIA_SMI_PATH} {WSL_NVIDIA_SMI_PATH}")
        raise typer.Exit(1)
