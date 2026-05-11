#!/usr/bin/env bash
# deploy.sh — Sync the plugin's individual skills into your local Claude skills folder.
#
# Each skill is symlinked individually into ~/.claude/skills/<skill-name>
# so Claude Code can detect them at the expected nesting level.
# The _shared/ folder is symlinked too (skills reference it via relative paths).
#
# Usage:
#   ./scripts/deploy.sh              # creates symlinks (recommended during dev)
#   ./scripts/deploy.sh --copy       # copies files instead
#   ./scripts/deploy.sh --unlink     # removes all symlinks created by this script

set -euo pipefail

# -----------------------------------------------------------------------------
# CONFIGURE: target directory for skills
# -----------------------------------------------------------------------------
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SKILLS_DIR="$REPO_ROOT/skills"
MODE="${1:-symlink}"

# Names of items in skills/ to symlink (skills + _shared)
# _shared is included because skills reference it via ../_shared/...
ITEMS=()
for dir in "$SOURCE_SKILLS_DIR"/*/; do
  ITEMS+=("$(basename "$dir")")
done

# Sanity checks
if [[ ! -d "$SOURCE_SKILLS_DIR" ]]; then
  echo "❌ Source skills directory not found: $SOURCE_SKILLS_DIR"
  exit 1
fi

if [[ ! -d "$CLAUDE_SKILLS_DIR" ]]; then
  echo "⚠️  Target skills directory does not exist: $CLAUDE_SKILLS_DIR"
  echo "    Create it with: mkdir -p \"$CLAUDE_SKILLS_DIR\""
  exit 1
fi

case "$MODE" in
  --unlink|unlink)
    echo "Removing symlinks from $CLAUDE_SKILLS_DIR..."
    for item in "${ITEMS[@]}"; do
      target="$CLAUDE_SKILLS_DIR/$item"
      if [[ -L "$target" ]]; then
        rm "$target"
        echo "  ✓ Removed symlink: $item"
      elif [[ -e "$target" ]]; then
        echo "  ⚠️  $item exists but is not a symlink. Skipping (remove manually if needed)."
      fi
    done
    # Also remove legacy "running-coach" symlink if it exists (from previous deploy.sh version)
    if [[ -L "$CLAUDE_SKILLS_DIR/running-coach" ]]; then
      rm "$CLAUDE_SKILLS_DIR/running-coach"
      echo "  ✓ Removed legacy symlink: running-coach"
    fi
    ;;

  --copy|copy)
    echo "Copying skills to $CLAUDE_SKILLS_DIR..."
    for item in "${ITEMS[@]}"; do
      source="$SOURCE_SKILLS_DIR/$item"
      target="$CLAUDE_SKILLS_DIR/$item"
      if [[ -e "$target" || -L "$target" ]]; then
        echo "  ⚠️  $target already exists. Skipping."
        continue
      fi
      cp -R "$source" "$target"
      echo "  ✓ Copied: $item"
    done
    ;;

  --symlink|symlink|"")
    echo "Creating symlinks in $CLAUDE_SKILLS_DIR..."
    # Clean up legacy "running-coach" symlink from old deploy.sh version
    if [[ -L "$CLAUDE_SKILLS_DIR/running-coach" ]]; then
      rm "$CLAUDE_SKILLS_DIR/running-coach"
      echo "  ✓ Cleaned legacy symlink: running-coach"
    fi
    for item in "${ITEMS[@]}"; do
      source="$SOURCE_SKILLS_DIR/$item"
      target="$CLAUDE_SKILLS_DIR/$item"
      if [[ -e "$target" || -L "$target" ]]; then
        echo "  ⚠️  $item already exists. Run './scripts/deploy.sh --unlink' first to refresh."
        continue
      fi
      ln -s "$source" "$target"
      echo "  ✓ Linked: $item -> $source"
    done
    echo ""
    echo "All edits in your repo are now live in Claude Code."
    echo "Note: skills without a SKILL.md (only README.md placeholders) won't appear in /skills yet."
    echo "      They will once you fill in their SKILL.md during migration."
    ;;

  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 [--symlink | --copy | --unlink]"
    exit 1
    ;;
esac
