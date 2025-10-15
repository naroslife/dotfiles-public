#!/usr/bin/env bash
# Docker Helper - Interactive docker operations with fzf
# Usage: dotfiles-docker-helper.sh or dotfiles docker

set -euo pipefail

# Script directory and root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common utilities
if [[ -f "$ROOT_DIR/lib/common.sh" ]]; then
    source "$ROOT_DIR/lib/common.sh"
else
    echo "Error: Could not find lib/common.sh" >&2
    exit 1
fi

# Check for required tools
require_command docker "Install docker: https://docs.docker.com/get-docker/"
require_command fzf "fzf should be installed via home-manager. Try: dotfiles apply"

# Docker operations menu
show_docker_menu() {
    local choice

    # Create menu with preview
    choice=$(cat << 'EOF' | fzf \
        --height=80% \
        --border=rounded \
        --header='Docker Helper - Select an operation' \
        --preview='echo {}' \
        --preview-window=up:3:wrap \
        --prompt='Docker > ' \
        --pointer='▶' \
        --marker='✓'
ps              List running containers
ps-all          List all containers (including stopped)
images          List all images
volumes         List all volumes
networks        List all networks
start           Start a stopped container
stop            Stop a running container
restart         Restart a container
remove          Remove a stopped container
exec            Execute command in running container
logs            View container logs
logs-follow     Follow container logs (live)
inspect         Inspect container details
stats           Show container resource usage
pull            Pull an image from registry
build           Build image from Dockerfile
compose-up      Start services (docker compose up)
compose-down    Stop services (docker compose down)
compose-logs    View compose logs
prune-containers Prune stopped containers
prune-images    Prune unused images
prune-volumes   Prune unused volumes
prune-all       Prune everything (containers, images, volumes)
system-df       Show docker disk usage
system-info     Show docker system information
EOF
)

    # Handle the selected operation
    if [[ -z "$choice" ]]; then
        log_info "No operation selected"
        return 0
    fi

    local operation
    operation=$(echo "$choice" | awk '{print $1}')

    log_info "Executing: $operation"
    echo ""

    case "$operation" in
        ps)
            docker ps
            ;;
        ps-all)
            docker ps -a
            ;;
        images)
            docker images
            ;;
        volumes)
            docker volume ls
            ;;
        networks)
            docker network ls
            ;;
        start)
            local container
            container=$(docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Start container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                docker start "$container"
                log_info "Container $container started"
            fi
            ;;
        stop)
            local container
            container=$(docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Stop container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                docker stop "$container"
                log_info "Container $container stopped"
            fi
            ;;
        restart)
            local container
            container=$(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Restart container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                docker restart "$container"
                log_info "Container $container restarted"
            fi
            ;;
        remove)
            local container
            container=$(docker ps -a --filter "status=exited" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Remove container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                if ask_yes_no "Remove container $container?"; then
                    docker rm "$container"
                    log_info "Container $container removed"
                fi
            fi
            ;;
        exec)
            local container
            container=$(docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Execute in container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                read -p "Command to execute [/bin/bash]: " -r cmd
                cmd=${cmd:-/bin/bash}
                docker exec -it "$container" $cmd
            fi
            ;;
        logs)
            local container
            container=$(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='View logs > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                read -p "Number of lines [100]: " -r lines
                lines=${lines:-100}
                docker logs --tail "$lines" "$container"
            fi
            ;;
        logs-follow)
            local container
            container=$(docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Follow logs > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                log_info "Following logs for $container (Ctrl-C to stop)"
                docker logs -f "$container"
            fi
            ;;
        inspect)
            local container
            container=$(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | tail -n +2 | fzf --height=40% --prompt='Inspect container > ' | awk '{print $1}')
            if [[ -n "$container" ]]; then
                docker inspect "$container" | less
            fi
            ;;
        stats)
            log_info "Showing container stats (Ctrl-C to stop)"
            docker stats
            ;;
        pull)
            read -p "Image name (e.g., nginx:latest): " -r image
            if [[ -n "$image" ]]; then
                docker pull "$image"
                log_info "Image $image pulled successfully"
            fi
            ;;
        build)
            read -p "Tag name (e.g., myapp:latest): " -r tag
            read -p "Dockerfile path [./Dockerfile]: " -r dockerfile
            dockerfile=${dockerfile:-./Dockerfile}
            if [[ -n "$tag" ]]; then
                docker build -t "$tag" -f "$dockerfile" .
                log_info "Image $tag built successfully"
            fi
            ;;
        compose-up)
            if [[ ! -f "docker-compose.yml" ]] && [[ ! -f "compose.yml" ]]; then
                log_error "No docker-compose.yml or compose.yml found in current directory"
                return 1
            fi
            log_info "Starting services with docker compose..."
            docker compose up -d
            log_info "Services started"
            ;;
        compose-down)
            if [[ ! -f "docker-compose.yml" ]] && [[ ! -f "compose.yml" ]]; then
                log_error "No docker-compose.yml or compose.yml found in current directory"
                return 1
            fi
            log_info "Stopping services with docker compose..."
            docker compose down
            log_info "Services stopped"
            ;;
        compose-logs)
            if [[ ! -f "docker-compose.yml" ]] && [[ ! -f "compose.yml" ]]; then
                log_error "No docker-compose.yml or compose.yml found in current directory"
                return 1
            fi
            log_info "Viewing compose logs (Ctrl-C to stop)"
            docker compose logs -f
            ;;
        prune-containers)
            log_warn "This will remove all stopped containers"
            if ask_yes_no "Continue?"; then
                docker container prune -f
                log_info "Stopped containers removed"
            fi
            ;;
        prune-images)
            log_warn "This will remove all unused images"
            if ask_yes_no "Continue?"; then
                docker image prune -a -f
                log_info "Unused images removed"
            fi
            ;;
        prune-volumes)
            log_warn "This will remove all unused volumes"
            if ask_yes_no "Continue?"; then
                docker volume prune -f
                log_info "Unused volumes removed"
            fi
            ;;
        prune-all)
            log_error "WARNING: This will remove all stopped containers, unused networks, images, and volumes!"
            if ask_yes_no "Are you absolutely sure?"; then
                docker system prune -a --volumes -f
                log_info "System pruned"
            else
                log_info "Prune cancelled"
            fi
            ;;
        system-df)
            docker system df
            ;;
        system-info)
            docker info
            ;;
        *)
            log_error "Unknown operation: $operation"
            return 1
            ;;
    esac

    echo ""
    log_info "Operation completed"
}

# Main entry point
main() {
    # Check if docker is running
    if ! docker info > /dev/null 2>&1; then
        die "Docker is not running" 1 "Start Docker daemon: sudo systemctl start docker (Linux) or start Docker Desktop (macOS/Windows)"
    fi

    # Show the menu
    show_docker_menu
}

# Run main
main "$@"
