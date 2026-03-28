#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>"
  exit 1
fi

USER="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$REPO_ROOT/ssh/config.template"
TARGET="${HOME}/.ssh/config.d/homelab"

mkdir -p "$(dirname "$TARGET")"
sed "s/{{USER}}/$USER/g" "$TEMPLATE" >"$TARGET"
chmod 600 "$TARGET"
echo "Written to $TARGET"

SSH_CONFIG="${HOME}/.ssh/config"
INCLUDE_LINE="Include config.d/*"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
if ! grep -qF "$INCLUDE_LINE" "$SSH_CONFIG"; then
  echo -e "$INCLUDE_LINE\n$(cat "$SSH_CONFIG")" >"$SSH_CONFIG"
  echo "Added Include line to $SSH_CONFIG"
fi
