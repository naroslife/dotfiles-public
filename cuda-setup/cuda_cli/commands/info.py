"""Info command - Display GPU and system information."""

import typer
from typing import Optional

from ..core.system import is_wsl2, get_wsl_distro_name, get_os_info, get_kernel_version
from ..core.driver import (
    get_driver_version,
    get_driver_cuda_version,
    get_gpu_name,
    DriverError,
)
from ..core.constants import CUDA_VERSION, MIN_WINDOWS_DRIVER, RECOMMENDED_DRIVER
from ..utils.output import (
    console,
    print_error,
    print_warning,
    print_header,
    print_json_output,
    print_driver_info_table,
    print_system_info_table,
)


def info(
    json_output: bool = typer.Option(
        False,
        "--json",
        help="Output information as JSON",
    ),
    full: bool = typer.Option(
        False,
        "--full",
        help="Include detailed specifications",
    ),
) -> None:
    """Display GPU, driver, and system information.

    Shows current GPU model, driver version, CUDA compatibility,
    and system details for WSL2 environment.
    """
    # Check WSL2
    if not is_wsl2():
        print_error("This tool is designed for WSL2 environments")
        raise typer.Exit(1)

    # Collect system information
    wsl_distro = get_wsl_distro_name()
    os_name, os_version = get_os_info()
    kernel_version = get_kernel_version()

    # Collect driver information
    try:
        driver_version = get_driver_version()
        cuda_version = get_driver_cuda_version()
        gpu_name = get_gpu_name()
    except DriverError as e:
        if not json_output:
            print_error(f"Failed to get driver information: {e}")
        driver_version = None
        cuda_version = None
        gpu_name = None

    # Build info dictionary
    info_dict = {
        "system": {
            "wsl_distribution": wsl_distro,
            "os_name": os_name,
            "os_version": os_version,
            "kernel_version": kernel_version,
        },
        "gpu": {
            "name": gpu_name or "Not detected",
        },
        "driver": {
            "version": driver_version or "Not detected",
            "cuda_version_supported": cuda_version or "Unknown",
        },
        "cuda": {
            "target_version": CUDA_VERSION,
            "min_driver_required": MIN_WINDOWS_DRIVER,
            "recommended_driver": RECOMMENDED_DRIVER,
        },
    }

    # Output as JSON if requested
    if json_output:
        print_json_output(info_dict)
        return

    # Pretty print with Rich
    print_header("CUDA Setup Information")

    # System information
    print_system_info_table(
        wsl_distro=wsl_distro,
        os_name=os_name,
        os_version=os_version,
        kernel_version=kernel_version,
    )

    console.print()

    # Driver information
    if driver_version:
        from ..core.driver import version_meets_minimum

        is_compatible = version_meets_minimum(driver_version, MIN_WINDOWS_DRIVER)

        print_driver_info_table(
            driver_version=driver_version,
            cuda_version=cuda_version,
            gpu_name=gpu_name,
            min_required=MIN_WINDOWS_DRIVER,
            recommended=RECOMMENDED_DRIVER,
            is_compatible=is_compatible,
        )
    else:
        print_warning("NVIDIA driver not detected")
        console.print("  Please install NVIDIA drivers on Windows")
        console.print("  Download: https://www.nvidia.com/Download/index.aspx")

    console.print()
