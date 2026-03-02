#!/usr/bin/env bash
set -euo pipefail

FORCE_INSTALL=false
WORKSPACE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-install)
      FORCE_INSTALL=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--force-install] <workspace-name>"
      exit 1
      ;;
    *)
      WORKSPACE_NAME="$1"
      shift
      ;;
  esac
done

if [ -z "$WORKSPACE_NAME" ]; then
  echo "Usage: $0 [--force-install] <workspace-name>"
  exit 1
fi
WORKSPACE_HOST="workspace-${WORKSPACE_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if the workspaces CLI is installed
if ! command -v workspaces >/dev/null 2>&1; then
  echo "Error: 'workspaces' command not found." >&2
  echo "Install it with: brew update && brew upgrade datadog-workspaces" >&2
  exit 1
fi

echo "=== Step 1/5: Checking if workspace ${WORKSPACE_NAME} exists ==="

# Check if the given workspace exists
if ! workspaces list | awk -v n="${WORKSPACE_NAME}" '$1 == n { found=1 } END { exit !found }'; then
  echo "Error: workspace '${WORKSPACE_NAME}' not found." >&2
  echo "" >&2
  workspaces list >&2
  echo "" >&2
  echo "Create it with: workspaces create ${WORKSPACE_NAME}" >&2
  exit 1
fi

echo
echo "=== Step 2/5: Install Vibe Kanban on workspace ==="
if [ "$FORCE_INSTALL" = true ] || ! ssh $WORKSPACE_HOST "test -d ~/vibe-kanban"; then
  scp "${SCRIPT_DIR}/install-vibe-kanban.sh" "${WORKSPACE_HOST}:~/install-vibe-kanban.sh"
  echo
  ssh -t $WORKSPACE_HOST "bash ~/install-vibe-kanban.sh ${WORKSPACE_NAME} && rm ~/install-vibe-kanban.sh && ~/vibe-kanban/start.sh"
else
  echo "~/vibe-kanban already exists on ${WORKSPACE_HOST}, skipping installation (use --force-install to override)"
  ssh -t $WORKSPACE_HOST "~/vibe-kanban/start.sh"
fi

echo
echo "=== Step 3/5: Forward SSH ports ==="
"${SCRIPT_DIR}/forward-ssh.sh" "${WORKSPACE_NAME}"


echo
echo "=== Step 4/5: Login into GitHub ==="
if ssh $WORKSPACE_HOST "gh auth status" &>/dev/null; then
  echo "Already logged into GitHub, skipping"
else
  ssh -t $WORKSPACE_HOST "gh auth login"
fi


echo
echo "=== Step 5/5: Login into ddbuild.io ==="
ssh -t $WORKSPACE_HOST "ddtool auth login --datacenter us1.ddbuild.io"

echo
echo "=== Setup complete ==="
echo "Open: http://localhost:42091"