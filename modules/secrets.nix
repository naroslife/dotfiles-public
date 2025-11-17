{
  config,
  pkgs,
  lib,
  ...
}:

{
  # sops-nix configuration for secrets management
  sops = {
    # Default sops file location
    defaultSopsFile = ../secrets/secrets.yaml;

    # Validate sops files at build time
    validateSopsFiles = true; # Set to true once you've created secrets.yaml

    # Age key configuration
    age = {
      # Use SSH host key for age decryption (most convenient)
      # This will automatically derive age key from your SSH key
      sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];

      # Alternatively, you can specify an age key file directly:
      # keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

      # Generate age key from SSH key if it doesn't exist
      generateKey = true;
    };

    # Define secrets and where they should be placed
    # These will be decrypted and made available at the specified paths
    secrets = {
      # API Keys as environment variables
      "api_keys/tavily" = {
        # Will be available at runtime via sops
        path = "${config.home.homeDirectory}/.config/api-keys/tavily";
      };

      "api_keys/morph" = {
        path = "${config.home.homeDirectory}/.config/api-keys/morph";
      };
    };
  };

  # Make secrets available as environment variables
  # These will be sourced by your shell
  home.sessionVariables = {
    TAVILY_API_KEY = "$(cat ${config.home.homeDirectory}/.config/api-keys/tavily 2>/dev/null || echo '')";
    MORPH_API_KEY = "$(cat ${config.home.homeDirectory}/.config/api-keys/morph 2>/dev/null || echo '')";
  };

  # Install sops package for manual secret editing
  home.packages = with pkgs; [
    sops
    age # For key management
    ssh-to-age # Convert SSH keys to age format
  ];
}
