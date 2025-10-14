"""Rich console output utilities for beautiful terminal display."""

import json
from typing import Any, Dict, Optional

from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich import box


# Create global console instance
console = Console()


def print_info(message: str) -> None:
    """Print info message in blue."""
    console.print(f"[blue][INFO][/blue] {message}")


def print_success(message: str) -> None:
    """Print success message in green with checkmark."""
    console.print(f"[green]✓[/green] {message}")


def print_warning(message: str) -> None:
    """Print warning message in yellow."""
    console.print(f"[yellow]⚠[/yellow]  {message}")


def print_error(message: str) -> None:
    """Print error message in red with X mark."""
    console.print(f"[red]✗[/red] {message}")


def print_highlight(message: str) -> None:
    """Print highlighted message in cyan."""
    console.print(f"[cyan][DRIVER][/cyan] {message}")


def print_header(title: str) -> None:
    """Print a header with separator line."""
    console.print()
    console.rule(f"[bold cyan]{title}[/bold cyan]")
    console.print()


def print_json_output(data: Dict[str, Any]) -> None:
    """Print data as formatted JSON.

    Args:
        data: Dictionary to output as JSON.
    """
    print(json.dumps(data, indent=2, default=str))


def create_info_table(title: str) -> Table:
    """Create a formatted table for displaying system information.

    Args:
        title: Title for the table.

    Returns:
        Rich Table object.
    """
    table = Table(title=title, box=box.ROUNDED, show_header=False)
    table.add_column("Property", style="cyan", no_wrap=True)
    table.add_column("Value", style="white")
    return table


def print_driver_info_table(
    driver_version: str,
    cuda_version: Optional[str],
    gpu_name: Optional[str],
    min_required: str,
    recommended: str,
    is_compatible: bool,
) -> None:
    """Print driver information in a formatted table.

    Args:
        driver_version: Current driver version.
        cuda_version: CUDA version supported by driver.
        gpu_name: GPU model name.
        min_required: Minimum required driver version.
        recommended: Recommended driver version.
        is_compatible: Whether driver is compatible.
    """
    table = create_info_table("Driver Information")

    if gpu_name:
        table.add_row("GPU", gpu_name)

    table.add_row("Windows Driver", driver_version)

    if cuda_version:
        table.add_row("Max CUDA Version", cuda_version)

    table.add_row("Min Required (CUDA 12.9)", min_required)
    table.add_row("Recommended", recommended)

    # Add compatibility status
    if is_compatible:
        status = "[green]✓ Compatible[/green]"
    else:
        status = "[red]✗ Not Compatible[/red]"
    table.add_row("Status", status)

    console.print(table)


def print_system_info_table(
    wsl_distro: str,
    os_name: str,
    os_version: str,
    kernel_version: str,
) -> None:
    """Print system information in a formatted table.

    Args:
        wsl_distro: WSL distribution name.
        os_name: Operating system name.
        os_version: OS version.
        kernel_version: Linux kernel version.
    """
    table = create_info_table("System Information")

    table.add_row("WSL Distribution", wsl_distro)
    table.add_row("OS", f"{os_name} {os_version}")
    table.add_row("Kernel", kernel_version)

    console.print(table)


def print_panel(message: str, title: str, style: str = "blue") -> None:
    """Print a message in a panel box.

    Args:
        message: Message to display.
        title: Panel title.
        style: Panel border style (color).
    """
    panel = Panel(
        message,
        title=title,
        border_style=style,
        box=box.ROUNDED,
    )
    console.print(panel)


def print_update_instructions(current_version: str, min_version: str, recommended: str) -> None:
    """Print driver update instructions.

    Args:
        current_version: Current driver version.
        min_version: Minimum required version.
        recommended: Recommended version.
    """
    print_header("Driver Update Required")

    print_error(f"Current driver ({current_version}) does not support CUDA 12.9")
    print_info(f"Minimum required: {min_version}")
    print_info(f"Recommended: {recommended} or newer")

    console.print()
    print_highlight("How to update your NVIDIA driver on Windows:")
    console.print()

    # Option 1
    console.print("[bold]Option 1: GeForce Experience (Easiest)[/bold]")
    console.print("  1. Open GeForce Experience on Windows")
    console.print("  2. Go to 'Drivers' tab")
    console.print("  3. Click 'Check for Updates'")
    console.print("  4. Download and install the latest driver")
    console.print()

    # Option 2
    console.print("[bold]Option 2: Manual Download[/bold]")
    console.print("  1. Visit: [link]https://www.nvidia.com/Download/index.aspx[/link]")
    console.print("  2. Select your GPU model")
    console.print("  3. Download the latest driver (Game Ready or Studio)")
    console.print("  4. Run the installer on Windows")
    console.print()

    # Option 3
    console.print("[bold]Option 3: Windows Update[/bold]")
    console.print("  1. Open Windows Settings → Update & Security")
    console.print("  2. Click 'Check for updates'")
    console.print("  3. Install any NVIDIA driver updates")
    console.print()

    print_warning("After updating the driver on Windows:")
    console.print("  1. Restart Windows (recommended)")
    console.print("  2. Restart WSL: [cyan]wsl --shutdown[/cyan] (in PowerShell)")
    console.print("  3. Relaunch Ubuntu")
    console.print("  4. Run [cyan]cuda-setup check[/cyan] again to verify")
    console.print()
