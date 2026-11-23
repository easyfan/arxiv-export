#!/usr/bin/env bash
# install.sh — arxiv-export Claude Code plugin installer
#
# Usage:
#   ./install.sh              # install to ~/.claude/
#   ./install.sh --dry-run    # preview without writing
#   ./install.sh --uninstall  # remove installed files
#   CLAUDE_DIR=/path ./install.sh  # custom target

set -euo pipefail

# ── Resolve real script dir (symlink-safe) ────────────────────────────────────
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
  link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# ── Config ────────────────────────────────────────────────────────────────────
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=false
UNINSTALL=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    --target=*)  CLAUDE_DIR="${arg#--target=}" ;;
    --help|-h)
      echo "Usage: ./install.sh [--dry-run] [--uninstall] [--target=<path>]"
      exit 0 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }
skip() { printf "  \033[2m– %s (up to date)\033[0m\n" "$*"; }
warn() { printf "  \033[33m! %s\033[0m\n" "$*"; }
run()  { $DRY_RUN || "$@"; }

SKILL_SRC="skills/arxiv-export"
SKILL_DST="skills/arxiv-export"

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "  arxiv-export — Claude Code plugin v$(grep '"version"' "$SCRIPT_DIR/package.json" | head -1 | grep -o '[0-9.]*')"
echo "  Target: $CLAUDE_DIR"
$DRY_RUN && echo "  Mode: DRY RUN (no files modified)"
echo ""

# ── Check Claude Code ─────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
  warn "'claude' CLI not found. Install Claude Code first: https://claude.ai/code"
  echo ""
fi

# ── Check TeX toolchain (optional; skill prompts to install on first run) ──────
if ! command -v tectonic &>/dev/null && ! command -v pdflatex &>/dev/null; then
  warn "No TeX engine found. The skill will offer to install one (e.g. 'brew install tectonic pandoc') on first run."
  echo ""
fi

# ── Uninstall ─────────────────────────────────────────────────────────────────
if $UNINSTALL; then
  echo "  Uninstalling..."
  skill_dst="$CLAUDE_DIR/$SKILL_DST"
  if [ -d "$skill_dst" ]; then
    run rm -rf "$skill_dst"
    ok "Removed $skill_dst"
  else
    skip "$SKILL_DST (not found)"
  fi
  echo ""
  echo "  Uninstall complete."
  echo ""
  exit 0
fi

# ── Install skill ─────────────────────────────────────────────────────────────
changed=0
skill_src="$SCRIPT_DIR/$SKILL_SRC"
skill_dst="$CLAUDE_DIR/$SKILL_DST"

if [ -f "$skill_dst/SKILL.md" ] && diff -q "$skill_src/SKILL.md" "$skill_dst/SKILL.md" &>/dev/null; then
  skip "$SKILL_DST"
else
  [ -d "$skill_dst" ] && printf "  Updating  %s...\n" "$SKILL_DST" || printf "  Installing %s...\n" "$SKILL_DST"
  run mkdir -p "$skill_dst"
  run cp -r "$skill_src/." "$skill_dst/"
  ok "$SKILL_DST → $skill_dst"
  changed=$((changed + 1))
fi

# ── Footer ────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo "  [dry-run] $changed file(s) would be modified."
else
  echo "  Done! $changed file(s) installed."
  echo ""
  echo "  Quick start — in Claude Code, point it at your Markdown paper:"
  echo "    \"用 arxiv-export 把 paper.md 导出成 arXiv 投稿包\""
  echo "    \"export paper.md to an arXiv LaTeX submission\""
  echo ""
  echo "  First run installs a TeX engine if missing (tectonic + pandoc recommended)."
fi
echo ""
