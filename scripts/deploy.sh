#!/usr/bin/env bash
# deploy.sh — Sync the plugin's skills/ directory into your local Claude skills folder.
#
# Usage:
#   ./scripts/deploy.sh              # creates a symlink (recommended during dev)
#   ./scripts/deploy.sh --copy       # copies files instead (safer for production-like testing)
#   ./scripts/deploy.sh --unlink     # removes the symlink

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURE: set this to your local Claude skills directory.
# Common locations on macOS:
#   - Claude Desktop:     ~/Library/Application Support/Claude/skills
#   - Claude Code config: ~/.claude/skills
# Adjust to match your setup.
# -----------------------------------------------------------------------------
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

# Plugin paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILLS_DIR="$REPO_ROOT/skills"
TARGET_DIR="$CLAUDE_SKILLS_DIR/running-coach"

MODE="${1:-symlink}"

# Sanity checks
if [[ ! -d "$SOURCE_SKILLS_DIR" ]]; then
  echo "❌ Source skills directory not found: $SOURCE_SKILLS_DIR"
  exit 1
fi

if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "⚠️  Claude skills directory does not exist: $CLAUDE_SKILLS_DIR"
  echo "    Create it first, or set CLAUDE_SKILLS_DIR environment variable to the correct path."
  echo "    Example: CLAUDE_SKILLS_DIR=~/Library/Application\\ Support/Claude/skills ./scripts/deploy.sh"
  exit 1
fi

case "$MODE" in
  --unlink|unlink)
    if [[ -L "$TARGET_DIR" ]]; then
      rm "$TARGET_DIR"
      echo "✓ Symlink removed: $TARGET_DIR"
    elif [[ -d "$TARGET_DIR" ]]; then
      echo "⚠️  $TARGET_DIR exists but is not a symlink. Refusing to delete."
      echo "    Remove manually if you're sure: rm -rf '$TARGET_DIR'"
      exit 1
    else
      echo "Nothing to unlink at $TARGET_DIR"
    fi
    ;;
  --copy|copy)
    if [[ -e "$TARGET_DIR" ]]; then
      echo "⚠️  $TARGET_DIR already exists. Remove it first or use a different mode."
      exit 1
    fi
    cp -R "$SOURCE_SKILLS_DIR" "$TARGET_DIR"
    echo "✓ Copied skills to: $TARGET_DIR"
    ;;
  --symlink|symlink|"")
    if [[ -e "$TARGET_DIR" || -L "$TARGET_DIR" ]]; then
      echo "⚠️  $TARGET_DIR already exists. Run './scripts/deploy.sh --unlink' first."
      exit 1
    fi
    ln -s "$SOURCE_SKILLS_DIR" "$TARGET_DIR"
    echo "✓ Symlink created: $TARGET_DIR -> $SOURCE_SKILLS_DIR"
    echo "  All edits in your repo are now live in Claude."
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [--symlink | --copy | --unlink]"
    exit 1
    ;;
esac
