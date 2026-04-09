"""Main CLI entry point for cuda-setup.

Modern CLI tool for CUDA 12.9 setup on WSL2 with rich terminal output
and comprehensive error handling.
"""

import typer
from typing import Optional

from . import __version__
from .commands.info import info
from .commands.check import check
from .commands.fix import fix


# Create main Typer app
app = typer.Typer(
    name="cuda-setup",
    help="Modern CLI tool for CUDA 12.9 setup on WSL2",
    add_completion=True,
    rich_markup_mode="rich",
    no_args_is_help=True,
)


def version_callback(value: bool) -> None:
    """Print version and exit."""
    if value:
        typer.echo(f"cuda-setup version {__version__}")
        raise typer.Exit()


@app.callback()
def main(
    version: Optional[bool] = typer.Option(
        None,
        "--version",
        "-V",
        callback=version_callback,
        is_eager=True,
        help="Show version and exit",
    ),
) -> None:
    """CUDA Setup CLI - Modern tool for CUDA 12.9 setup on WSL2.

    A developer-friendly Python CLI with rich terminal output for setting up
    CUDA 12.9 on WSL2. Features automatic nvidia-smi fixes, driver compatibility
    checking, and comprehensive system diagnostics.

    Examples:

      # Show system and GPU information
      cuda-setup info

      # Check driver compatibility with CUDA 12.9
      cuda-setup check

      # Fix nvidia-smi segfault issue
      cuda-setup fix

      # Get help for any command
      cuda-setup check --help
    """
    pass


# Register commands directly
app.command(name="info", help="Show GPU and driver information")(info)
app.command(name="check", help="Check driver compatibility with CUDA 12.9")(check)
app.command(name="fix", help="Fix nvidia-smi segfault issue")(fix)


if __name__ == "__main__":
    app()
