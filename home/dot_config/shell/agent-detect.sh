#!/usr/bin/env bash
# Agent detection — sourced early by .zshrc and .bashrc
# Covers Claude Code, Codex, Copilot, and generic AI_AGENT env vars

is_agent() {
  [[ -n "${CLAUDE:-}" ]] || [[ -n "${CODEX:-}" ]] || [[ -n "${COPILOT:-}" ]] || [[ -n "${AI_AGENT:-}" ]]
}

if is_agent; then
  export SMART_REMINDERS=0
fi
