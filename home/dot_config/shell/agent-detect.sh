#!/usr/bin/env bash
# Agent detection — sourced by shell rc files before loading shell functions
# Covers: Claude Code, Codex, GitHub Copilot, and generic AI_AGENT sentinel.

is_agent() {
  [[ -n "${CLAUDE:-}" ]] || [[ -n "${CODEX:-}" ]] || [[ -n "${COPILOT:-}" ]] || [[ -n "${AI_AGENT:-}" ]]
}

# Suppress interactive features (smart reminders) in agent mode
if is_agent; then
  export SMART_REMINDERS=0
fi
