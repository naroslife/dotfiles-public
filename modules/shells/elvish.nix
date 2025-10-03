{ config, pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    elvish # Friendly interactive shell with structured data pipelines
  ];

  # Elvish configuration files are managed through home.file in core.nix
  # The .config/elvish directory is already configured to be sourced from ./elvish
  home.file.".config/elvish/rc.elv".text = ''
    # Basic elvish configuration

    # Add custom paths
    set paths = [
      $@paths
      $E:HOME/.local/bin
      $E:HOME/.cargo/bin
      $E:HOME/.npm-global/bin
      ./node_modules/.bin
    ]

    # Environment variables
    set E:KUBECONFIG = $E:HOME/.kube/config
    set E:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow'
    set E:EDITOR = code

    # Load starship prompt if available
    if (has-external starship) {
      eval (starship init elvish)
    }

    # Load zoxide if available
    if (has-external zoxide) {
      eval (zoxide init elvish | slurp)
    }

    # Modern CLI aliases
    fn l { |@a| eza -l --icons --git -a $@a }
    fn la { |@a| tree $@a }
    fn lt { |@a| eza --tree --level=2 --long --icons --git $@a }
    fn cat { |@a| bat $@a }

    # Git aliases
    fn gc { |@a| git commit -m $@a }
    fn gst { |@a| git status $@a }
    fn gp { |@a| git push origin HEAD $@a }

    # Directory navigation
    fn .. { cd .. }
    fn ... { cd ../.. }
    fn .... { cd ../../.. }

    # Docker aliases
    fn dps { |@a| docker ps $@a }
    fn dco { |@a| docker compose $@a }

    # K8s aliases
    fn k { |@a| kubectl $@a }
    fn kg { |@a| kubectl get $@a }
    fn kd { |@a| kubectl describe $@a }

    # Misc aliases
    fn cl { clear }
    fn v { |@a| nvim $@a }
    fn http { |@a| xh $@a }
  '';
}
