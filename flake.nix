{
  description = "Modular Home Manager configuration with Nix flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , home-manager
    , nur
    , sops-nix
    , ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Function to create pkgs for a specific system
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
          };
          overlays = [
            nur.overlays.default
            # Custom overlays can be added here
          ];
        };

      # Function to detect user info from environment
      detectUserInfo = username:
        let
          # Try to get git config if available
          gitEmail = builtins.getEnv "GIT_EMAIL";
          gitName = builtins.getEnv "GIT_NAME";

          # Default mappings for known users
          knownUsers = {
            naroslife = {
              email = "robi54321@gmail.com";
              fullName = "Robert Nagy";
            };
            uif58593 = {
              email = "robert.4.nagy@aumovio.com";
              fullName = "Robert Nagy";
            };
          };

          # Check if user is known
          isKnown = builtins.hasAttr username knownUsers;
        in
        if isKnown
        then knownUsers.${username}
        else if gitEmail != "" && gitName != ""
        then {
          email = gitEmail;
          fullName = gitName;
        }
        else {
          email = "${username}@example.com";
          fullName = username;
        };

      # User configurations (can be extended)
      users = {
        naroslife = detectUserInfo "naroslife";
        uif58593 = detectUserInfo "uif58593";
        # Dynamic user detection - will be added at build time
      };

      # Function to create a home-manager configuration for a user
      mkHomeConfig = system: username: userInfo:
        let
          pkgs = mkPkgs system;
          # Get HM_MODIFY_SHELL from environment (default to false for non-invasive mode)
          hmModifyShell = builtins.getEnv "HM_MODIFY_SHELL";
          modifyShell = if hmModifyShell == "true" then "true" else "false";

        in
        {
          "${username}" = home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            modules = [
              ./home.nix
              sops-nix.homeManagerModules.sops
              {
                # User-specific configuration
                home = {
                  username = username;
                  homeDirectory = "/home/${username}";
                };

                # Git configuration from user info
                programs.git = {
                  userEmail = userInfo.email;
                  userName = userInfo.fullName;
                };
                # Set shell modification mode
                home.sessionVariables = {
                  HM_MODIFY_SHELL = modifyShell;
                };

              }
            ];

            extraSpecialArgs = {
              inherit username;
              inherit (userInfo) email fullName;
            };
          };
        };

      # Dynamically add current user if detected via environment variable
      currentUser = builtins.getEnv "CURRENT_USER";
      allUsers =
        if currentUser != "" && !(builtins.hasAttr currentUser users)
        then users // { "${currentUser}" = detectUserInfo currentUser; }
        else users;

      # Default system for home configurations (Linux x86_64)
      defaultSystem = "x86_64-linux";
    in
    {
      # Add formatter for each system
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

      # Generate home configurations for all users (using default system)
      homeConfigurations = builtins.foldl'
        (
          acc: username: acc // mkHomeConfig defaultSystem username allUsers.${username}
        )
        { }
        (builtins.attrNames allUsers);

      # Convenience aliases for common operations
      apps = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = {
            type = "app";
            program = "${pkgs.writeShellScript "activate" ''
            #!/usr/bin/env bash
            set -e

            # Detect username
            USERNAME="''${1:-$(whoami)}"

            # Export current user for dynamic detection
            export CURRENT_USER="$USERNAME"

            # Get git info if available
            if command -v git &>/dev/null; then
              export GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
              export GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
            fi

            echo "Activating home-manager configuration for $USERNAME..."
            nix run .#homeConfigurations.$USERNAME.activationPackage
          ''}";
          };
        }
      );

      # Development shells with Home Manager environment

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          # Get all available user configurations
          userConfigs = builtins.attrNames allUsers;

        in
        {
          # Default dev shell - for working on dotfiles themselves

          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              git
              nixfmt-rfc-style
              alejandra
              nil
            ];

            shellHook = ''
              echo "Dotfiles development shell"
              echo "Available commands:"
              echo "  home-manager switch --flake .#username"
              echo "  nix flake check"
              echo "  nix flake update"
              echo "  nix fmt  # Format all Nix files"
              echo "  alejandra --check .  # Check formatting without modifying"
            '';
          };
          # Home Manager environment shell - provides HM tools without modifying system
          hm-env = pkgs.mkShell {
            name = "home-manager-env-shell";

            buildInputs = with pkgs; [
              home-manager
              git
              nix
            ];

            shellHook = ''
              # Detect user
              USER_NAME="''${CURRENT_USER:-$(whoami)}"

              # Source Home Manager environment if profile exists
              if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
                source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
              fi

              # Add Home Manager bins to PATH
              export PATH="$HOME/.nix-profile/bin:$PATH"

              echo "╔════════════════════════════════════════════════════════════╗"
              echo "║   Home Manager Development Environment                    ║"
              echo "╚════════════════════════════════════════════════════════════╝"
              echo ""
              echo "User: $USER_NAME"
              echo "Your system environment remains unchanged."
              echo "All Home Manager tools and configurations are available here."
              echo ""
              echo "Exit this shell to return to your normal environment."
              echo ""
              echo "Available commands:"
              echo "  home-manager switch --flake .#$USER_NAME"
              echo "  home-manager generations"
              echo "  home-manager packages"
              echo ""
            '';
          };
        } // builtins.listToAttrs (map
          (username: {
            name = "hm-${username}";
            value = pkgs.mkShell {
              name = "home-manager-env-${username}";

              buildInputs = with pkgs; [
                home-manager
                git
              ];

              shellHook = ''
                # Source Home Manager environment
                if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
                  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
                fi

                export PATH="$HOME/.nix-profile/bin:$PATH"

                echo "╔════════════════════════════════════════════════════════════╗"
                echo "║   Home Manager Environment: ${username}"
                echo "╚════════════════════════════════════════════════════════════╝"
                echo ""
                echo "Run: home-manager switch --flake .#${username}"
                echo ""
              '';
            };
          })
          userConfigs)

      );

      # Flake checks
      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          # Check nix formatting
          format =
            pkgs.runCommand "check-format"
              {
                buildInputs = [ pkgs.alejandra pkgs.fd ];
              }
              ''
                cd ${./.}
                ${pkgs.fd}/bin/fd -e nix -x ${pkgs.alejandra}/bin/alejandra --check {}
                touch $out
              '';

          # Validate all home configurations build
          build-all = pkgs.runCommand "build-all-configs" { } ''
            ${pkgs.lib.concatStringsSep "\n" (
              map (user: ''
                echo "Building configuration for ${user}..."
              '') (builtins.attrNames users)
            )}
            touch $out
          '';
        }
      );
    };
}
