{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    # === Development - Java ===
    jdk17
    maven
    gradle

    # === Development - C/C++ ===
    # Compilers & Build Systems
    gcc
    # clang
    cmake
    ninja # Small build system focused on speed
    meson # Fast and user-friendly build system
    bazel # Google's build system for large-scale projects
    autoconf
    automake
    libtool
    pkg-config

    # C/C++ Libraries
    boost
    fmt # Modern C++ formatting library
    spdlog # Fast C++ logging library
    catch2 # Modern C++ test framework
    gtest # Google Test framework
    eigen # C++ template library for linear algebra
    opencv # Computer vision library
    qt6.full
    gtk4
    glfw # OpenGL/Vulkan window and input library
    glew # OpenGL Extension Wrangler
    vulkan-headers
    vulkan-loader
    glibc.dev
    openssl
    ncurses.dev
    libcap.dev # POSIX capabilities library
    systemd.dev

    # C/C++ Tools
    clang-tools # clang-format, clang-tidy, etc.
    cppcheck # Static analysis tool for C/C++
    valgrind # Memory debugging and profiling
    gdb # GNU debugger
    lldb # LLVM debugger
    rr # Record and replay debugger for C/C++ (time-travel debugging)
    sccache # Shared compilation cache for C/C++/Rust (speeds up builds)
    strace # Trace system calls and signals
    ltrace # Trace library calls
    perf-tools # Performance analysis tools

    # === Development - Other Languages ===
    go
    nodejs
    rustup # Rust toolchain installer

    # === Language-specific Package Managers ===
    # Python with common packages
    (python3.withPackages (ps: with ps; [
      # Code Quality & Formatting
      pycodestyle # Python style checker
      black # Uncompromising Python formatter
      mypy # Static type checker
      pylint # Comprehensive code analysis
      flake8 # Style guide enforcement
      isort # Import sorting
      autopep8 # PEP 8 auto-formatter

      # Testing
      pytest # Testing framework
      pytest-cov # Coverage plugin for pytest
      pytest-xdist # Parallel test execution
      hypothesis # Property-based testing
      tox # Test automation

      # HTTP & Networking
      requests # HTTP library
      httpx # Modern async HTTP client
      urllib3 # HTTP client
      aiohttp # Async HTTP client/server

      # Data Science & Analysis
      numpy # Numerical computing
      pandas # Data manipulation and analysis
      matplotlib # Plotting library
      scipy # Scientific computing

      # CLI & TUI
      textual # Modern TUI framework
      rich # Rich text and formatting
      click # CLI creation kit
      typer # Modern CLI framework (built on click)
      prompt-toolkit # Interactive CLI building

      # Development Tools
      ipython # Enhanced interactive Python shell
      # pdbpp # Not available in nixpkgs - use ipdb instead
      ipdb # IPython-enabled debugger (better alternative to pdbpp)
      poetry-core # Poetry build backend
      setuptools # Package development
      wheel # Built package format
      pip # Package installer

      # Utilities
      pyyaml # YAML parser
      toml # TOML parser
      jinja2 # Template engine
      python-dateutil # Date/time utilities
      tqdm # Progress bars
    ]))
    pipx # Install and run Python applications in isolated environments


    # Ruby with tmuxinator
    (ruby.withPackages (rbps: with rbps; [
      tmuxinator # Manage tmux sessions easily
    ]))
  ];

  # Tool versions (for asdf/rtx compatibility)
  home.file.".tool-versions".source = ../../.tool-versions;

  # Note: NPM configuration is managed in home.nix

  # Environment variables for languages
  home.sessionVariables = {
    # NPM_CONFIG_PREFIX is configured in modules/environment.nix

    # Prefer system pkg-config and ensure Ubuntu pc dirs are visible
    PKG_CONFIG = "/usr/bin/pkg-config";
    PKG_CONFIG_PATH = "/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig";
  };
}
