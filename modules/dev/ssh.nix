{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;

    # Global match blocks
    matchBlocks = {
      # Default settings for all hosts
      "*" = {
        # Control master for connection sharing (huge performance boost)
        # controlMaster = "auto";
        # controlPath = "~/.ssh/control-%r@%h:%p";
        # controlPersist = "10m";

        # Agent configuration
        # forwardAgent = true;

        # Connection settings
        # serverAliveInterval = 15;
        # serverAliveCountMax = 3;

        # Security settings
        # hashKnownHosts = true;

        # sendEnv = [ "LANG" "LC_*" ];
        extraOptions = {
          # Legacy MAC support (only if needed for old servers)
          MACs = "+hmac-md5,hmac-sha1";

          # Disable X11 forwarding by default (security)
          ForwardX11 = "yes";
          ForwardX11Trusted = "yes";

          # IPv4 only (set to "any" if you need IPv6)
          AddressFamily = "inet";

          # Connection timeout
          ConnectTimeout = "20";

          # Security improvements
          StrictHostKeyChecking = "ask";
          # PasswordAuthentication = "no";
          # ChallengeResponseAuthentication = "no";

          # Compression for slow connections
          Compression = "yes";

          # Keep alive
          TCPKeepAlive = "yes";

          # SSH agent configuration (add keys automatically)
          AddKeysToAgent = "yes";

          # Use modern ciphers and key exchange
          Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr";
          KexAlgorithms = "curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256";
        };
      };

      # Example bastion host configuration
      "bastion" = {
        hostname = "bastion.domain.com";
        user = "ec2-user";
        identityFile = "~/.ssh/id_rsa";
        port = 22;
      };

      # GitHub configuration
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          PreferredAuthentications = "publickey";
        };
      };

      # GitLab configuration
      "gitlab.com" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          PreferredAuthentications = "publickey";
        };
      };

      # Example of jump host configuration
      "internal-*" = {
        proxyJump = "bastion";
        user = "admin";
        extraOptions = {
          StrictHostKeyChecking = "no";
        };
      };

      # Development servers (less strict)
      "dev-*" = {
        extraOptions = {
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
          LogLevel = "ERROR";
        };
      };

      # Local network hosts
      "192.168.*" = {
        extraOptions = {
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
        };
      };

      # Raspberry Pi's
      "pi pi-*" = {
        user = "pi";
        extraOptions = {
          PreferredAuthentications = "publickey,password";
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
