#!/bin/bash
set -e

# Claude Code setup — trust /workspace and install native build
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
    jq '.projects["/workspace"].hasTrustDialogAccepted = true' "$CLAUDE_SETTINGS" \
        > /tmp/.claude_settings_tmp.json \
        && mv /tmp/.claude_settings_tmp.json "$CLAUDE_SETTINGS"
else
    mkdir -p "$HOME/.claude"
    printf '{"projects":{"/workspace":{"hasTrustDialogAccepted":true}}}' > "$CLAUDE_SETTINGS"
fi
# Install/update native binary (no re-download if already current)
claude install 2>/dev/null || true

# Gemini CLI setup
mkdir -p ~/.gemini
cat > ~/.gemini/settings.json << 'EOF'
{
  "security": {
    "auth": {
      "selectedType": "gemini-api-key"
    }
  }
}
EOF

# Add AI proxy env vars to .bashrc
cat >> ~/.bashrc << 'EOF'

# AI Proxy environment variables
export GEMINI_API_KEY=$(cat ~/.ai-proxy-api-key 2>/dev/null)
export GOOGLE_API_KEY="$GEMINI_API_KEY"
export GOOGLE_GEMINI_BASE_URL="https://ai-proxy.infra.corp.arista.io/"
EOF

# Export for current session
export GEMINI_API_KEY=$(cat ~/.ai-proxy-api-key 2>/dev/null)
export GOOGLE_API_KEY="$GEMINI_API_KEY"
export GOOGLE_GEMINI_BASE_URL="https://ai-proxy.infra.corp.arista.io/"

# Install Python dependencies
pip3 install --user --break-system-packages -r arista_rfp/requirements.txt

# gemini -p "/ide install" -y
