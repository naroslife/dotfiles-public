#!/bin/bash
# Carapace initialization script

# Initialize carapace for bash
if [ -n "$BASH_VERSION" ]; then
    source <(carapace _carapace)
fi

# Initialize carapace for zsh
if [ -n "$ZSH_VERSION" ]; then
    source <(carapace _carapace zsh)
fi
