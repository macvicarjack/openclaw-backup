#!/bin/zsh
if [ -d "$HOME/.openclaw/.git" ]; then
  echo "ERROR: ~/.openclaw/.git exists (this will explode disk). Remove it now." >&2
  exit 1
fi
exit 0
