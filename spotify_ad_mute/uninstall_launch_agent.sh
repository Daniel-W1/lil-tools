#!/bin/zsh

set -euo pipefail

DEST_FILE="$HOME/Library/LaunchAgents/local.spotify-mute.plist"
LABEL="local.spotify-mute"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || launchctl bootout "gui/$(id -u)" "$DEST_FILE" 2>/dev/null || true
rm -f "$DEST_FILE"

echo "Removed LaunchAgent: $DEST_FILE"
