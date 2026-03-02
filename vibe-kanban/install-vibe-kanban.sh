#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <workspace-name>"
  exit 1
fi

name="$1"

INSTALL_DIR="${HOME}/vibe-kanban"
CONFIG_DIR="${HOME}/.local/share/vibe-kanban"
PORT="42091"

echo "This will install Vibe Kanban into ${INSTALL_DIR}"
echo

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

need_cmd node
need_cmd npm

mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# Create start.sh
cat > "${INSTALL_DIR}/start.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="\${ROOT_DIR}/.vibe-kanban.pid"
LOG_FILE="\${ROOT_DIR}/vibe-kanban.log"
PORT=${PORT}

if [[ -f "\${PID_FILE}" ]] && kill -0 "\$(cat "\${PID_FILE}")" 2>/dev/null; then
  echo "Vibe Kanban Worker already running (pid \$(cat "\${PID_FILE}"))."
  echo "Open: http://localhost:\${PORT}"
  exit 0
fi

rm -f "\${PID_FILE}"

cd "\${ROOT_DIR}"

if lsof -nP -iTCP:"\${PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Error: port \${PORT} is already in use:"
  lsof -nP -iTCP:"\${PORT}" -sTCP:LISTEN
  echo
fi

# Start server
nohup env PORT=\${PORT} npx vibe-kanban > "\${LOG_FILE}" 2>&1 &

echo \$! > "\${PID_FILE}"

echo
echo "Vibe Kanban Worker started (detached) at: http://localhost:\${PORT}"
echo "Logs: ./logs.sh"
echo "Stop: ./stop.sh"
EOF

# Create stop.sh
cat > "${INSTALL_DIR}/stop.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${ROOT_DIR}/.vibe-kanban.pid"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "Vibe Kanban Worker not running (no pid file)."
  exit 0
fi

PID="$(cat "${PID_FILE}")"

if kill -0 "${PID}" 2>/dev/null; then
  kill "${PID}"
  echo "Sent SIGTERM to vibe-kanban (pid ${PID})."
else
  echo "Stale pid file (pid ${PID} not running)."
fi

rm -f "${PID_FILE}"
EOF

# Create logs.sh
cat > "${INSTALL_DIR}/logs.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${ROOT_DIR}/vibe-kanban.log"

if [[ ! -f "${LOG_FILE}" ]]; then
  echo "No log file yet at ${LOG_FILE}."
  exit 1
fi

tail -f "${LOG_FILE}"
EOF

chmod +x "${INSTALL_DIR}/start.sh" "${INSTALL_DIR}/stop.sh" "${INSTALL_DIR}/logs.sh"

# Create configuration
mkdir -p "${CONFIG_DIR}"
cat > "${CONFIG_DIR}/config.json" <<EOF
{
  "config_version": "v8",
  "theme": "SYSTEM",
  "executor_profile": {
    "executor": "CLAUDE_CODE"
  },
  "disclaimer_acknowledged": false,
  "onboarding_acknowledged": false,
  "remote_onboarding_acknowledged": false,
  "notifications": {
    "sound_enabled": true,
    "push_enabled": true,
    "sound_file": "PHONE_VIBRATION"
  },
  "editor": {
    "editor_type": "CURSOR",
    "custom_command": null,
    "remote_ssh_host": "workspace-${name}",
    "remote_ssh_user": null,
    "auto_install_extension": true
  },
  "github": {
    "pat": null,
    "oauth_token": null,
    "username": null,
    "primary_email": null,
    "default_pr_base": "main"
  },
  "analytics_enabled": false,
  "workspace_dir": "${DATADOG_ROOT}",
  "last_app_version": "0.1.19",
  "show_release_notes": false,
  "language": "BROWSER",
  "git_branch_prefix": "${REAL_USER:-$USER}",
  "showcases": {
    "seen_features": []
  },
  "pr_auto_description_enabled": true,
  "pr_auto_description_prompt": "Update the PR that was just created with a better title and description.\nThe PR number is #{pr_number} and the URL is {pr_url}.\n\nFollow template from .github/PULL_REQUEST_TEMPLATE.md. Keep it concise.\n\nUse the gh pr edit CLI tool.",
  "commit_reminder_enabled": true,
  "commit_reminder_prompt": "There are uncommitted changes. Please stage and commit them now with a descriptive commit message.\n\nAfter commit, remember to update Vibe Kanban (add follow tasks if needed, update existing tasks if needed).",
  "send_message_shortcut": "ModifierEnter"
}
EOF

# Setup MCP servers
cat > "${HOME}/.claude.json" <<EOF
{
  "mcpServers": {
    "vibe_kanban": {
      "command": "npx",
      "args": [
        "-y",
        "vibe-kanban@latest",
        "--mcp"
      ]
    }
  }
}
EOF

echo
echo "Installation complete."
echo
echo "  cd ${INSTALL_DIR}"
echo "    ./start.sh (to start in the background)"
echo "    ./logs.sh  (to see logs)"
echo "    ./stop.sh"