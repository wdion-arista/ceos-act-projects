#!/bin/bash
set -e

# Claude Code setup — only runs if claude is installed
if command -v claude &>/dev/null; then
    CLAUDE_SETTINGS="$HOME/.claude/settings.json"
    if [ -f "$CLAUDE_SETTINGS" ]; then
        jq ".projects[\"${CONTAINER_WORKSPACE_FOLDER:-$PWD}\"].hasTrustDialogAccepted = true" \
            "$CLAUDE_SETTINGS" > /tmp/.claude_settings_tmp.json \
            && mv /tmp/.claude_settings_tmp.json "$CLAUDE_SETTINGS"
    else
        mkdir -p "$HOME/.claude"
        printf "{\"projects\":{\"%s\":{\"hasTrustDialogAccepted\":true}}}" \
            "${CONTAINER_WORKSPACE_FOLDER:-$PWD}" > "$CLAUDE_SETTINGS"
    fi
    claude install 2>/dev/null || true
fi
