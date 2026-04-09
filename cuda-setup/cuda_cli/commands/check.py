"""Check command - Verify driver compatibility with CUDA 12.9."""

import typer

from ..core.system import is_wsl2
from ..core.driver import check_driver_compatibility, DriverError
from ..core.nvidia_smi import fix_nvidia_smi, NvidiaSmiError
from ..utils.output import (
    console,
    print_info,
    print_success,
    print_error,
    print_warning,
    print_header,
    print_json_output,
    print_driver_info_table,
    print_update_instructions,
)


def check(
    json_output: bool = typer.Option(
        False,
        "--json",
        help="Output results as JSON",
    ),
    no_fix: bool = typer.Option(
        False,
        "--no-fix",
        help="Don't auto-fix nvidia-smi segfault",
    ),
    verbose: bool = typer.Option(
        False,
        "--verbose",
        "-v",
        help="Show detailed information",
    ),
) -> None:
    """Check if NVIDIA driver is compatible with CUDA 12.9.

    Verifies that the Windows NVIDIA driver meets minimum requirements
    for CUDA 12.9 installation. Automatically fixes nvidia-smi segfault
    issues if detected (unless --no-fix is specified).
    """
    # Check WSL2
    if not is_wsl2():
        if json_output:
            print_json_output({"error": "Not running on WSL2", "compatible": False})
        else:
            print_error("This tool is designed for WSL2 environments")
        raise typer.Exit(1)

    if not json_output:
        print_header("NVIDIA Driver Compatibility Check")

    # Fix nvidia-smi if needed (unless --no-fix specified)
    if not no_fix:
        if verbose and not json_output:
            print_info("Checking nvidia-smi...")

        try:
            success, message = fix_nvidia_smi(verbose=verbose)
            if verbose and not json_output:
                if success:
                    print_success(message)
                else:
                    print_warning(message)
        except NvidiaSmiError as e:
            if json_output:
                print_json_output({"error": str(e), "compatible": False})
            else:
                print_error(f"nvidia-smi fix failed: {e}")
                console.print()
                print_info("Try running: [cyan]cuda-setup fix[/cyan]")
            raise typer.Exit(1)

    # Check driver compatibility
    if not json_output:
        print_info("Checking Windows NVIDIA driver...")

    try:
        is_compatible, message, info = check_driver_compatibility()
    except DriverError as e:
        if json_output:
            print_json_output({"error": str(e), "compatible": False})
        else:
            print_error(str(e))
            console.print()
            if "not found" in str(e).lower():
                print_info("Please install NVIDIA drivers on Windows first")
                console.print("  Download: https://www.nvidia.com/Download/index.aspx")
        raise typer.Exit(1)

    # Output results
    if json_output:
        output_data = {
            "compatible": is_compatible,
            "message": message,
            **info,
        }
        print_json_output(output_data)
    else:
        console.print()

        # Print driver information table
        driver_version = info.get("driver_version")
        if driver_version:
            print_driver_info_table(
                driver_version=driver_version,
                cuda_version=info.get("cuda_version"),
                gpu_name=info.get("gpu_name"),
                min_required=info["min_required"],
                recommended=info["recommended"],
                is_compatible=is_compatible,
            )

            console.print()

            if is_compatible:
                print_success(message)
                console.print()
                print_info("You can proceed with CUDA 12.9 installation")

                # Suggest update if not on recommended version
                if driver_version != info["recommended"]:
                    from ..core.driver import version_meets_minimum

                    if not version_meets_minimum(driver_version, info["recommended"]):
                        console.print()
                        print_info(
                            f"Consider updating to driver {info['recommended']}+ "
                            "for latest features and bug fixes"
                        )
                        console.print(
                            "  Download: https://www.nvidia.com/Download/index.aspx"
                        )
            else:
                print_error(message)
                console.print()
                print_update_instructions(
                    current_version=driver_version,
                    min_version=info["min_required"],
                    recommended=info["recommended"],
                )
                raise typer.Exit(1)
        else:
            print_error("Could not determine driver version")
            raise typer.Exit(1)

    console.print()
