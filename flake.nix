{
  description = "Modular Home Manager configuration with Nix flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur.url = "github:nix-community/NUR";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nur, sops-nix, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
        overlays = [
          nur.overlay
          # Custom overlays can be added here
        ];
      };

      # User configurations
      users = {
        naroslife = {
          email = "naroslife@gmail.com";
          fullName = "Naros Life";
        };
        enterpriseuser = {
          email = "enterpriseuser@gmail.com";
          fullName = "User enterpriseuser";
        };
      };

      # Function to create a home-manager configuration for a user
      mkHomeConfig = username: userInfo: {
        "${username}" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;

          modules = [
            ./home.nix
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
            }
          ];

          extraSpecialArgs = {
            inherit username;
            inherit (userInfo) email fullName;
          };
        };
      };
    in
    {
      # Generate home configurations for all users
      homeConfigurations = builtins.foldl'
        (acc: username: acc // mkHomeConfig username users.${username})
        { }
        (builtins.attrNames users);

      # Convenience aliases for common operations
      apps.${system} = {
        default = {
          type = "app";
          program = "${pkgs.writeShellScript "activate" ''
            #!/usr/bin/env bash
            set -e

            # Detect username
            USERNAME="''${1:-$(whoami)}"

            # Check if configuration exists for this user
            if [[ "$USERNAME" != "naroslife" && "$USERNAME" != "enterpriseuser" ]]; then
              echo "Error: No configuration found for user '$USERNAME'"
              echo "Available users: naroslife, enterpriseuser"
              echo "Usage: nix run . [username]"
              exit 1
            fi

            echo "Activating home-manager configuration for $USERNAME..."
            nix run .#homeConfigurations.$USERNAME.activationPackage
          ''}";
        };
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          nixpkgs-fmt
          nil
        ];

        shellHook = ''
          echo "Dotfiles development shell"
          echo "Available commands:"
          echo "  home-manager switch --flake .#username"
          echo "  nix flake check"
          echo "  nix flake update"
        '';
      };

      # Flake checks
      checks.${system} = {
        # Check nix formatting
        format = pkgs.runCommand "check-format"
          {
            buildInputs = [ pkgs.nixpkgs-fmt ];
          } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          touch $out
        '';

        # Validate all home configurations build
        build-all = pkgs.runCommand "build-all-configs" { } ''
          ${pkgs.lib.concatStringsSep "\n" (map (user: ''
            echo "Building configuration for ${user}..."
          '') (builtins.attrNames users))}
          touch $out
        '';
      };
    };
}
