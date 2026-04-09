# Home Manager Development Shell
# This shell provides access to the Home Manager environment without modifying system files
# Usage: nix-shell or nix develop (for flakes)
{pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  name = "home-manager-dev-shell";

  buildInputs = with pkgs; [
    home-manager
    git
    nix
  ];

  shellHook = ''
    # Source Home Manager environment if profile exists
    if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
      source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    fi

    # Add Home Manager bins to PATH
    export PATH="$HOME/.nix-profile/bin:$PATH"

    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║   Home Manager Development Shell                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Your system environment remains unchanged."
    echo "All Home Manager tools and configurations are available here."
    echo ""
    echo "Exit this shell to return to your normal environment."
    echo ""
  '';
}
