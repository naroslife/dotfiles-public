{ config, pkgs, lib, ... }:
{
  imports = [
    ./core.nix
    ./environment.nix
    ./shells
    ./dev
    ./cli
  ] ++ lib.optional (builtins.pathExists /proc/sys/fs/binfmt_misc/WSLInterop) ./wsl.nix;
}
