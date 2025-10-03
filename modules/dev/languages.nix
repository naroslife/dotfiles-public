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
      pycodestyle # Python style checker
      black # Uncompromising Python formatter
      mypy # Static type checker
      pytest # Testing framework
      requests # HTTP library
    ]))

    # Ruby with tmuxinator
    (ruby.withPackages (rbps: with rbps; [
      tmuxinator # Manage tmux sessions easily
    ]))
  ];

  # Tool versions (for asdf/rtx compatibility)
  home.file.".tool-versions".source = ../../.tool-versions;

  # NPM configuration for user-level global installs
  home.file.".npmrc".text = ''
    prefix=''${HOME}/.npm-global
  '';

  # Environment variables for languages
  home.sessionVariables = {
    # NPM_CONFIG_PREFIX is configured in modules/environment.nix

    # Prefer system pkg-config and ensure Ubuntu pc dirs are visible
    PKG_CONFIG = "/usr/bin/pkg-config";
    PKG_CONFIG_PATH = "/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig";
  };
}
