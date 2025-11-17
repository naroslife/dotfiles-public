{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Common shell aliases shared across bash and zsh
  commonAliases = {
    # Home Manager
    hm = "nix run home-manager/master -- switch --flake . --impure";

    # Runtime history tool switching (consistent across shells)
    use-atuin = "switch_history atuin";
    use-mcfly = "switch_history mcfly";
    history-status = "switch_history status";

    # Sudo with Nix environment preservation
    nsudo = "sudo env PATH='$PATH'";
    sudo-nix = "sudo env PATH='$PATH'";

    # File operations
    la = "tree";
    cat = "bat";
    l = "eza -l --icons --git -a";
    lt = "eza --tree --level=2 --long --icons --git";
    ltree = "eza --tree --level=2 --icons --git";

    # File operations with modern tools
    find = "fd";
    grep = "rg";
    ls = "eza";

    # Git aliases
    gc = "git commit -m";
    gca = "git commit -a -m";
    gp = "git push origin HEAD";
    gpu = "git pull origin";
    gst = "git status";
    glog = "git log --graph --topo-order --pretty='%w(100,0,6)%C(yellow)%h%C(bold)%C(black)%d %C(cyan)%ar %C(green)%an%n%C(bold)%C(white)%s %N' --abbrev-commit";
    gdiff = "git diff";
    gco = "git checkout";
    gb = "git branch";
    gba = "git branch -a";
    gadd = "git add";
    ga = "git add -p";
    gcoall = "git checkout -- .";
    gr = "git remote";
    gre = "git reset";

    # Docker
    dco = "docker compose";
    dps = "docker ps";
    dpa = "docker ps -a";
    dl = "docker ps -l -q";
    dx = "docker exec -it";

    # Directory navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";
    "......" = "cd ../../../../..";

    # K8s
    k = "kubectl";
    ka = "kubectl apply -f";
    kg = "kubectl get";
    kd = "kubectl describe";
    kdel = "kubectl delete";
    kl = "kubectl logs -f";
    kgpo = "kubectl get pod";
    kgd = "kubectl get deployments";
    kc = "kubectx";
    ke = "kubectl exec -it";
    kcns = "kubectl config set-context --current --namespace";

    # Misc
    http = "xh";
    cl = "clear";
    v = "nvim";
    nm = "nmap -sC -sV -oN nmap";
    rr = "ranger";

    # Modern CLI replacements
    df = "duf";
    du = "dust";
    ps = "procs";
    top = "btm";
    htop = "btm";
    ping = "gping";
    dig = "dog";

    # Git improvements
    gd = "git diff";
    gdt = "git difftool";

    # Next-Client launcher with restored environment variables
    nextclient = "~/dotfiles-public/wsl-fixes/test-restored-vars.sh";

    # Dotfiles management scripts
    # VSCode extension selector - interactive TUI for managing VSCode extensions
    vscode-ext = "python ${config.home.homeDirectory}/dotfiles-public/scripts/vscode-extension-selector.py";

    # Claude session cleaner - removes old Claude AI session files
    claude-clean = "python ${config.home.homeDirectory}/dotfiles-public/scripts/claude-session-cleaner.py";

    # CUDA development tools (cross-platform)
    # Test CUDA installation and runtime
    cuda-test = "bash ${config.home.homeDirectory}/dotfiles-public/cuda-setup/test-cuda.sh";

    # Install CUDA toolkit and drivers
    cuda-install = "bash ${config.home.homeDirectory}/dotfiles-public/cuda-setup/install-cuda.sh";

    # Compile and test CUDA programs
    cuda-compile-test = "bash ${config.home.homeDirectory}/dotfiles-public/cuda-setup/compile-test.sh";
  };
in
{
  # Apply aliases to both bash and zsh
  programs.bash.shellAliases = commonAliases;
  programs.zsh.shellAliases = commonAliases;
}
