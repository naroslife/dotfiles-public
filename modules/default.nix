{ config, pkgs, lib, ... }:
{
  imports = [
    ./defaults.nix # Single source of truth for all default values
    ./core.nix
    ./environment.nix
    # ./user-config.nix
    ./secrets.nix
    ./validation.nix
    ./shells
    ./dev
    ./cli
  ] ++ lib.optional (builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop) ./wsl.nix;
}
