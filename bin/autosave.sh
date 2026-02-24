#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${HOME}/.openclaw"
SNAP_DIR="${STATE_DIR}/snapshots"
LOG_DIR="${STATE_DIR}/autosave_logs"
TS="$(date '+%Y-%m-%d_%H-%M-%S')"

BACKUP_REPO="${HOME}/openclaw-backup"   # <-- separate repo OUTSIDE ~/.openclaw
KEEP_SNAPSHOTS=10

mkdir -p "$LOG_DIR" "$SNAP_DIR"
RUN_LOG="${LOG_DIR}/autosave_${TS}.log"
LATEST_LOG="${LOG_DIR}/autosave.latest.log"

exec > >(tee "$RUN_LOG" "$LATEST_LOG") 2>&1

notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"OpenClaw Autosave\"" >/dev/null 2>&1 || true
}

echo "=== autosave start: $TS ==="

# 1) Snapshot (short-term rewind point)
cd "$STATE_DIR"
SNAP="${SNAP_DIR}/snapshot_${TS}.tgz"
tar -czf "$SNAP" --exclude='./autosave_logs' --exclude='./snapshots' --exclude='./.git' .
echo "Snapshot written: $SNAP"

# Cap snapshots aggressively
cd "$SNAP_DIR"
COUNT=$(ls -1 2>/dev/null | wc -l | tr -d ' ')
if [ "$COUNT" -gt "$KEEP_SNAPSHOTS" ]; then
  ls -1t | tail -n +$((KEEP_SNAPSHOTS+1)) | while IFS= read -r f; do rm -f -- "$f"; done
  echo "Pruned snapshots to last $KEEP_SNAPSHOTS"
fi

# 2) GitHub backup (ONLY stable small files) in separate repo
mkdir -p "$BACKUP_REPO"
cd "$BACKUP_REPO"

# initialize repo if needed
if [ ! -d ".git" ]; then
  git init
  git branch -M main || true
fi

# sync safe files from ~/.openclaw
rsync -a --delete \
  --exclude='snapshots/' \
  --exclude='media/' \
  --exclude='browser/' \
  --exclude='logs/' \
  --exclude='workspace/' \
  --exclude='workspace_*' \
  --exclude='extensions/' \
  --exclude='extensions-backups/' \
  --exclude='*.tgz' \
  "${STATE_DIR}/openclaw.json" \
  "${STATE_DIR}/node.json" \
  "${STATE_DIR}/exec-approvals.json" \
  "${STATE_DIR}/exec-approvals.json.bak" \
  "${STATE_DIR}/devices" \
  "${STATE_DIR}/identity" \
  "${STATE_DIR}/agents" \
  "${STATE_DIR}/subagents" \
  "${STATE_DIR}/bin" \
  "${STATE_DIR}/update-check.json" \
  ./ 2>/dev/null || true

git add -A

if git diff --cached --quiet; then
  echo "No backup changes to commit."
else
  git commit -m "autosave ${TS}" --no-gpg-sign || true
  echo "Backup committed."
fi

# push if remote exists
if git remote get-url origin >/dev/null 2>&1; then
  echo "Pushing backup to origin/main..."
  git push -u origin main || notify "Autosave push failed (check GitHub auth)"
else
  echo "No origin remote set for ${BACKUP_REPO}. Set it once, then pushes will work."
fi

echo "=== autosave end: $TS ==="
