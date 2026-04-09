{ config
, pkgs
, lib
, ...
}: {
  programs.ssh = {
    enable = true;

    includes = [ ~/.ssh/.ssh_config_local ];

    # Global match blocks
    matchBlocks = {
      # Default settings for all hosts
      "*" = {
        user = "uif58593"; # Default SSH user

        compresssion = true;

        # Control master for connection sharing (huge performance boost)
        controlMaster = "auto";
        controlPath = "~/.ssh/control-%r@%h:%p";
        controlPersist = "10m";

        forwardX11 = true;
        forwardX11Trusted = true;

        # IPv4 only (set to "any" if you need IPv6)
        addressFamily = "inet";

        # Agent configuration
        forwardAgent = true;

        # Connection settings
        serverAliveInterval = 20;
        serverAliveCountMax = 3;

        # sendEnv = [ "LANG" "LC_*" ];
        extraOptions = {
          # Security improvements
          StrictHostKeyChecking = "ask";
          # PasswordAuthentication = "no";
          # ChallengeResponseAuthentication = "no";

          # Keep alive
          TCPKeepAlive = "yes";

          # SSH agent configuration (add keys automatically)
          AddKeysToAgent = "yes";

          # Use modern ciphers and key exchange
          Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
          KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
        };
      };
    };
  };

  # SSH-related packages
  home.packages = with pkgs; [
    sshfs # Mount remote filesystems over SSH
    ssh-copy-id # Copy SSH keys to remote hosts
    mosh # Mobile shell (better for unreliable connections)
    autossh # Automatically restart SSH sessions
  ];

  # Create SSH directory with correct permissions
  home.file.".ssh/.keep" = {
    text = "";
    onChange = ''
      chmod 700 ~/.ssh
    '';
  };
}
