#!/bin/zsh
set -euo pipefail
SNAPDIR="$HOME/.openclaw/snapshots"
KEEP="${1:-200}"

[ -d "$SNAPDIR" ] || exit 0

cd "$SNAPDIR"
COUNT=$(ls -1 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -le "$KEEP" ]; then
  exit 0
fi

# Delete everything older than newest $KEEP
ls -1t | tail -n +$((KEEP+1)) | while IFS= read -r f; do
  rm -f -- "$f"
done
