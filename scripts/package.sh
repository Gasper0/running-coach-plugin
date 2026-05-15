#!/usr/bin/env bash
# package.sh — Generate distribution-ready zips for the plugin.
#
# Two modes:
#   1. Individual skill zips (for claude.ai → Skills upload)
#      Each skill is packaged standalone, with _shared/ inlined when referenced.
#   2. Plugin zip (for claude.ai/Cowork → "Upload plugin")
#      The whole plugin packaged as a single zip, preserving _shared/ as a folder.
#
# Path references ../_shared/X.md are rewritten to _shared/X.md in the
# packaged skill versions. Source files in the repo are NEVER modified.
#
# Usage:
#   ./scripts/package.sh                  # all 5 skills + plugin zip
#   ./scripts/package.sh training-tracker # one skill only
#   ./scripts/package.sh --plugin         # plugin zip only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
DIST_DIR="$REPO_ROOT/dist"
SHARED_DIR="$SKILLS_DIR/_shared"
PLUGIN_NAME="running-coach-plugin"

# Cross-platform sed in-place editing
if [[ "$(uname)" == "Darwin" ]]; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

# Sanity checks
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "❌ Skills directory not found: $SKILLS_DIR"
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "❌ 'zip' command not found. Install with: brew install zip"
  exit 1
fi

# Determine mode
PACKAGE_PLUGIN_ONLY=false
SKILLS_TO_PACKAGE=()

if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--plugin" ]]; then
    PACKAGE_PLUGIN_ONLY=true
  else
    SKILLS_TO_PACKAGE=("$@")
  fi
else
  # No args: package all skills + plugin zip
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    [[ "$skill_name" == "_shared" ]] && continue
    SKILLS_TO_PACKAGE+=("$skill_name")
  done
fi

mkdir -p "$DIST_DIR"

# ─────────────────────────────────────────────────────────────
# Individual skill zips
# ─────────────────────────────────────────────────────────────

if [[ "$PACKAGE_PLUGIN_ONLY" == "false" ]] && [[ ${#SKILLS_TO_PACKAGE[@]} -gt 0 ]]; then
  echo "📦 Packaging ${#SKILLS_TO_PACKAGE[@]} skill(s) to $DIST_DIR/"
  echo ""

  for skill_name in "${SKILLS_TO_PACKAGE[@]}"; do
    src_dir="$SKILLS_DIR/$skill_name"
    temp_dir="$DIST_DIR/$skill_name"

    if [[ ! -d "$src_dir" ]]; then
      echo "⚠️  Skill not found: $skill_name (skipped)"
      continue
    fi

    if [[ ! -f "$src_dir/SKILL.md" ]]; then
      echo "⚠️  $skill_name has no SKILL.md (skipped)"
      continue
    fi

    echo "▶  $skill_name"

    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"

    cp "$src_dir/SKILL.md" "$temp_dir/SKILL.md"

    if [[ -d "$src_dir/references" ]]; then
      cp -R "$src_dir/references" "$temp_dir/references"
    fi

    if [[ -d "$src_dir/scripts" ]]; then
      cp -R "$src_dir/scripts" "$temp_dir/scripts"
    fi

    # Detect _shared/ references
    needs_shared=false
    if grep -q '\.\./_shared/' "$temp_dir/SKILL.md" 2>/dev/null; then
      needs_shared=true
    fi
    if [[ -d "$temp_dir/references" ]]; then
      if grep -rq '\.\./_shared/' "$temp_dir/references" 2>/dev/null; then
        needs_shared=true
      fi
    fi

    if [[ "$needs_shared" == "true" ]]; then
      if [[ ! -d "$SHARED_DIR" ]]; then
        echo "   ❌ Skill references ../_shared/ but $SHARED_DIR not found"
        rm -rf "$temp_dir"
        exit 1
      fi

      echo "   → Inlining _shared/"
      cp -R "$SHARED_DIR" "$temp_dir/_shared"

      "${SED_INPLACE[@]}" 's|\.\./_shared/|_shared/|g' "$temp_dir/SKILL.md"

      if [[ -d "$temp_dir/references" ]]; then
        find "$temp_dir/references" -name "*.md" -type f -print0 | \
          while IFS= read -r -d '' file; do
            "${SED_INPLACE[@]}" 's|\.\./_shared/|_shared/|g' "$file"
          done
      fi
    else
      echo "   → No _shared/ references"
    fi

    cd "$DIST_DIR"
    rm -f "${skill_name}.zip"
    zip -rq "${skill_name}.zip" "$skill_name"
    cd - > /dev/null

    rm -rf "$temp_dir"

    size=$(du -h "$DIST_DIR/${skill_name}.zip" | cut -f1)
    echo "   ✓ dist/${skill_name}.zip ($size)"
    echo ""
  done
fi

# ─────────────────────────────────────────────────────────────
# Plugin zip (whole plugin as one zip)
# ─────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]] || [[ "$PACKAGE_PLUGIN_ONLY" == "true" ]]; then
  echo "📦 Packaging full plugin to $DIST_DIR/${PLUGIN_NAME}.zip"
  echo ""

  temp_plugin_dir="$DIST_DIR/$PLUGIN_NAME"

  rm -rf "$temp_plugin_dir"
  mkdir -p "$temp_plugin_dir"

  for item in .claude-plugin .mcp.json skills config.example.json README.md LICENSE; do
    if [[ -e "$REPO_ROOT/$item" ]]; then
      cp -R "$REPO_ROOT/$item" "$temp_plugin_dir/"
      echo "   + $item"
    fi
  done

  # Clean any cruft
  find "$temp_plugin_dir" -name ".DS_Store" -delete 2>/dev/null || true
  find "$temp_plugin_dir" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
  find "$temp_plugin_dir" -name "*.pyc" -delete 2>/dev/null || true

  cd "$DIST_DIR"
  rm -f "${PLUGIN_NAME}.zip"
  zip -rq "${PLUGIN_NAME}.zip" "$PLUGIN_NAME"
  cd - > /dev/null

  rm -rf "$temp_plugin_dir"

  size=$(du -h "$DIST_DIR/${PLUGIN_NAME}.zip" | cut -f1)
  echo ""
  echo "   ✓ dist/${PLUGIN_NAME}.zip ($size)"
fi

# ─────────────────────────────────────────────────────────────
# Final summary
# ─────────────────────────────────────────────────────────────

echo ""
echo "✅ Done."
echo ""

if [[ -d "$DIST_DIR" ]] && ls "$DIST_DIR"/*.zip >/dev/null 2>&1; then
  echo "Generated zips:"
  ls -lh "$DIST_DIR"/*.zip
  echo ""
  echo "Next steps:"
  echo "  Individual skills → claude.ai → Settings → Capabilities → Skills → Upload skill"
  echo "  Plugin zip       → claude.ai/Cowork → Customize → Personal plugins → + → Upload plugin"
fi
