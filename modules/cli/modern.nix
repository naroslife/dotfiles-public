{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # === Modern CLI Replacements ===
    bat # cat with syntax highlighting and Git integration
    eza # Modern ls replacement with colors and git status
    fd # User-friendly find alternative
    ripgrep # Fast grep replacement written in Rust
    zoxide # Smarter cd command that learns your habits
    duf # Disk usage/free utility with better UI than df
    dust # Intuitive du replacement showing disk usage tree
    procs # Modern ps replacement with tree view and search
    bottom # Graphical process/system monitor (like htop but more features)
    htop-vim # htop with vim keybindings
    lsof # List open files and network connections
    sampler # Terminal-based visual dashboard for monitoring systems
    pv # Monitor progress of data through pipes

    # === Network Tools ===
    xh # User-friendly HTTP client (like HTTPie but faster)
    httpie # User-friendly HTTP client with intuitive syntax
    nmap # Network discovery and security scanning
    rustscan # Fast port scanner that pipes to nmap
    bandwhich # Terminal bandwidth utilization monitor
    gping # Ping with graph visualization
    dog # DNS client like dig but with colorful output
    netcat # TCP/IP swiss army knife
    wireshark # Network protocol analyzer
    insomnia # REST and GraphQL API client with GUI

    # === Text/Data Processing ===
    jq # JSON processor
    yq-go # YAML/JSON/XML/CSV processor (like jq for YAML)
    fx # Interactive JSON viewer with mouse support
    miller # Like awk/sed/cut/join for CSV, TSV, and JSON
    choose # Human-friendly alternative to cut/awk for selecting fields
    most # Pager like less but with multiple windows
    sad # CLI search and replace with diff preview (Space Age sed)
    visidata # Terminal spreadsheet for exploring and arranging tabular data
  ];

  # Modern tool configurations
  home.sessionVariables = {
    # BAT_THEME is configured in modules/environment.nix
    DELTA_FEATURES = "+side-by-side";
  };

  # Modern tool config files
  home.file.".config/bottom/bottom.toml".text = ''
    [flags]
    dot_marker = false

    [colors]
    table_header_color = "LightBlue"
    all_cpu_color = "Red"
    avg_cpu_color = "Green"
    cpu_core_colors = ["LightMagenta", "LightYellow", "LightCyan", "LightGreen", "LightBlue", "LightRed", "Cyan", "Green", "Blue", "Red"]
  '';
}
