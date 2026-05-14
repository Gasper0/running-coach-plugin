#!/usr/bin/env bash
# package.sh — Generate claude.ai-ready zips for each skill in the plugin.
#
# Each skill is packaged as a standalone .zip:
#   - SKILL.md (with rewritten paths)
#   - references/
#   - scripts/ (if present)
#   - _shared/ (only if the skill references ../_shared/...)
#
# Path references ../_shared/X.md are rewritten to _shared/X.md in the
# packaged version. Source files in the repo are NEVER modified.
#
# Output: dist/<skill-name>.zip — ready to upload at:
#   claude.ai → Settings → Capabilities → Skills → Upload skill
#
# Usage:
#   ./scripts/package.sh                 # package all skills
#   ./scripts/package.sh training-tracker # package one skill only

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
DIST_DIR="$REPO_ROOT/dist"
SHARED_DIR="$SKILLS_DIR/_shared"

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

# Determine target skills
if [[ $# -gt 0 ]]; then
  SKILLS_TO_PACKAGE=("$@")
else
  SKILLS_TO_PACKAGE=()
  for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    [[ "$skill_name" == "_shared" ]] && continue
    SKILLS_TO_PACKAGE+=("$skill_name")
  done
fi

# Prepare dist dir
mkdir -p "$DIST_DIR"

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
    echo "⚠️  $skill_name has no SKILL.md (skipped — only README placeholder?)"
    continue
  fi

  echo "▶  $skill_name"

  # Clean and recreate temp dir
  rm -rf "$temp_dir"
  mkdir -p "$temp_dir"

  # Copy SKILL.md
  cp "$src_dir/SKILL.md" "$temp_dir/SKILL.md"

  # Copy references/ if it exists
  if [[ -d "$src_dir/references" ]]; then
    cp -R "$src_dir/references" "$temp_dir/references"
  fi

  # Copy scripts/ if it exists (e.g. race-strategy/scripts/parse_gpx.py)
  if [[ -d "$src_dir/scripts" ]]; then
    cp -R "$src_dir/scripts" "$temp_dir/scripts"
  fi

  # Detect if SKILL.md or any reference uses ../_shared/
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

    echo "   → Inlining _shared/ (skill references shared resources)"
    cp -R "$SHARED_DIR" "$temp_dir/_shared"

    # Rewrite path references: ../_shared/X.md → _shared/X.md
    "${SED_INPLACE[@]}" 's|\.\./_shared/|_shared/|g' "$temp_dir/SKILL.md"

    # Also rewrite in references/*.md if present
    if [[ -d "$temp_dir/references" ]]; then
      find "$temp_dir/references" -name "*.md" -type f -print0 | \
        while IFS= read -r -d '' file; do
          "${SED_INPLACE[@]}" 's|\.\./_shared/|_shared/|g' "$file"
        done
    fi
  else
    echo "   → No _shared/ references (skipping inline)"
  fi

  # Create the zip
  cd "$DIST_DIR"
  rm -f "${skill_name}.zip"
  zip -rq "${skill_name}.zip" "$skill_name"
  cd - > /dev/null

  # Cleanup temp dir
  rm -rf "$temp_dir"

  size=$(du -h "$DIST_DIR/${skill_name}.zip" | cut -f1)
  echo "   ✓ dist/${skill_name}.zip ($size)"
  echo ""
done

echo "✅ Done."
echo ""
echo "Next steps:"
echo "  1. Go to claude.ai → Settings → Capabilities → Skills"
echo "  2. Click 'Upload skill' for each zip in dist/"
echo "  3. Upload them one by one (5 skills total)"
echo ""
ls -lh "$DIST_DIR"/*.zip 2>/dev/null || echo "(no zips generated)"
