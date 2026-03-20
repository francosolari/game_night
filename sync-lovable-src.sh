#!/usr/bin/env bash
set -euo pipefail

REMOTE_NAME="lovable"
REMOTE_URL="https://github.com/francosolari/game-night-web.git"
REMOTE_BRANCH="main"
TARGET_PARENT="apps/web"
TARGET_SRC="$TARGET_PARENT/src"

if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
fi

git fetch "$REMOTE_NAME"

rm -rf "$TARGET_SRC"
mkdir -p "$TARGET_PARENT"

git archive "$REMOTE_NAME/$REMOTE_BRANCH" src | tar -x -C "$TARGET_PARENT"

echo "Synced $REMOTE_NAME/$REMOTE_BRANCH:src -> $TARGET_SRC"