#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
TEMPLATE_FILE="$SCRIPT_DIR/launchd/local.spotify-mute.plist.template"
DEST_DIR="$HOME/Library/LaunchAgents"
DEST_FILE="$DEST_DIR/local.spotify-mute.plist"
LOG_FILE="$HOME/Library/Logs/spotify-mute.log"
LABEL="local.spotify-mute"

mkdir -p "$DEST_DIR"
mkdir -p "${LOG_FILE:h}"

escaped_script_dir=${SCRIPT_DIR//|/\\|}
escaped_log_file=${LOG_FILE//|/\\|}

sed \
	-e "s|__REPO_PATH__|$escaped_script_dir|g" \
	-e "s|__LOG_PATH__|$escaped_log_file|g" \
	"$TEMPLATE_FILE" > "$DEST_FILE"

launchctl bootout "gui/$(id -u)" "$DEST_FILE" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST_FILE"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed LaunchAgent: $DEST_FILE"
echo "Logs: $LOG_FILE"
