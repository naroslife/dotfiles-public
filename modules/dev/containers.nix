{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # === Container & Cloud Tools ===
    docker-compose
    lazydocker # Terminal UI for docker and docker-compose
    kubectl # Kubernetes CLI
    kubectx # Quickly switch between kubectl contexts
    k9s # Terminal UI for Kubernetes clusters
    helm # Kubernetes package manager

    # === Database Tools ===
    pgcli # PostgreSQL CLI with auto-completion and syntax highlighting
    usql # Universal CLI for SQL databases (PostgreSQL, MySQL, SQLite, etc.)
  ];

  # Environment variables
  home.sessionVariables = {
    KUBECONFIG = "$HOME/.kube/config";
  };
}
