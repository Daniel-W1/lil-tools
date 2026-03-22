#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
APPLE_SCRIPT="$SCRIPT_DIR/spotify_muter.applescript"
BLACKLIST_FILE="$SCRIPT_DIR/blacklist.tsv"

exec /usr/bin/osascript "$APPLE_SCRIPT" "$BLACKLIST_FILE"
