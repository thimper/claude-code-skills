#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_NAME="$(basename "$SCRIPT_DIR")"
SKILLS_BASE="$HOME/claude-skills"
ZSHRC="$HOME/.zshrc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

WRAPPER_MARKER="# claude-skills: auto-add-dir wrapper"

WRAPPER_FUNC="${WRAPPER_MARKER}
claude() {
  local dirs=()
  for repo in ~/claude-skills/*/; do
    dirs+=(--add-dir \"\$repo\")
  done
  command claude \"\${dirs[@]}\" \"\$@\"
}"

usage() {
  echo "Usage: $0 [--uninstall]"
  echo
  echo "Install:    Clone repo into ~/claude-skills/ and add claude wrapper to ~/.zshrc"
  echo "Uninstall:  Remove repo and claude wrapper from ~/.zshrc"
}

has_wrapper() {
  grep -qF "$WRAPPER_MARKER" "$ZSHRC" 2>/dev/null
}

# Check if a claude() function referencing claude-skills already exists (any variant)
has_claude_skills_func() {
  grep -q 'claude()' "$ZSHRC" 2>/dev/null && grep -q 'claude-skills' "$ZSHRC" 2>/dev/null
}

install() {
  # Step 1: Ensure repo is under ~/claude-skills/
  if [[ "$SCRIPT_DIR" != "$SKILLS_BASE"/* ]]; then
    mkdir -p "$SKILLS_BASE"
    # Check if any existing symlink already points to this repo
    local existing_link=""
    for link in "$SKILLS_BASE"/*/; do
      link="${link%/}"
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$SCRIPT_DIR" ]; then
        existing_link="$link"
        break
      fi
    done
    if [ -n "$existing_link" ]; then
      echo -e "Already linked: ${GREEN}$existing_link${NC} -> $SCRIPT_DIR"
    elif [ -L "$SKILLS_BASE/$REPO_NAME" ] || [ -e "$SKILLS_BASE/$REPO_NAME" ]; then
      echo -e "  ${YELLOW}skip${NC} $SKILLS_BASE/$REPO_NAME already exists"
    else
      echo -e "Symlinking: ${GREEN}$SKILLS_BASE/$REPO_NAME${NC} -> $SCRIPT_DIR"
      ln -s "$SCRIPT_DIR" "$SKILLS_BASE/$REPO_NAME"
      echo -e "  ${GREEN}linked${NC} $SKILLS_BASE/$REPO_NAME"
    fi
  else
    echo -e "Repo already under ~/claude-skills/: ${GREEN}$SCRIPT_DIR${NC}"
  fi

  # Step 2: Add wrapper function to .zshrc
  if has_wrapper; then
    echo -e "${YELLOW}claude wrapper already in ~/.zshrc, skipping.${NC}"
  elif has_claude_skills_func; then
    # Replace existing claude-skills wrapper with standardized version
    echo -e "${YELLOW}Found existing claude-skills wrapper, replacing with standard version...${NC}"
    local tmp
    tmp=$(mktemp)
    awk '
      /^#.*claude-skills/ || /^#.*claude skills/ { marker=1; next }
      /^claude\(\)/ && !marker { marker=1 }
      marker && /^claude\(\)/ { infunc=1; next }
      marker && !infunc { infunc=1; next }
      infunc && /^\}/ { infunc=0; marker=0; next }
      infunc { next }
      { print }
    ' "$ZSHRC" > "$tmp"
    # Remove trailing blank lines
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" > "$ZSHRC"
    rm "$tmp"
    echo "" >> "$ZSHRC"
    echo "$WRAPPER_FUNC" >> "$ZSHRC"
    echo -e "${GREEN}Replaced with standard claude wrapper in ~/.zshrc${NC}"
  else
    echo "" >> "$ZSHRC"
    echo "$WRAPPER_FUNC" >> "$ZSHRC"
    echo -e "${GREEN}Added claude wrapper function to ~/.zshrc${NC}"
  fi

  echo
  echo -e "${GREEN}Done!${NC} Run ${YELLOW}source ~/.zshrc${NC} or open a new terminal to activate."
  echo "All skill repos under ~/claude-skills/ will be auto-loaded by Claude Code."
}

uninstall() {
  # Step 1: Remove repo symlink from ~/claude-skills/ (only if it's a symlink pointing to this repo)
  local found=0
  for link in "$SKILLS_BASE"/*/; do
    link="${link%/}"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$SCRIPT_DIR" ]; then
      rm "$link"
      echo -e "${RED}Removed${NC} symlink $link"
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    local target="$SKILLS_BASE/$REPO_NAME"
    if [ -d "$target" ] && [ "$target" = "$SCRIPT_DIR" ]; then
      echo -e "${YELLOW}Repo is directly in ~/claude-skills/, not removing directory.${NC}"
      echo -e "Remove manually: rm -rf $target"
    else
      echo -e "${YELLOW}No symlink found for this repo in ~/claude-skills/${NC}"
    fi
  fi

  # Step 2: Remove wrapper function from .zshrc
  if has_wrapper || has_claude_skills_func; then
    local tmp
    tmp=$(mktemp)
    awk '
      /^#.*claude-skills/ || /^#.*claude skills/ { marker=1; next }
      /^claude\(\)/ && !marker { marker=1 }
      marker && /^claude\(\)/ { infunc=1; next }
      marker && !infunc { infunc=1; next }
      infunc && /^\}/ { infunc=0; marker=0; next }
      infunc { next }
      { print }
    ' "$ZSHRC" > "$tmp"
    # Remove trailing blank lines left behind
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" > "$ZSHRC"
    rm "$tmp"
    echo -e "${RED}Removed${NC} claude wrapper from ~/.zshrc"
  else
    echo -e "${YELLOW}No claude wrapper found in ~/.zshrc${NC}"
  fi

  echo -e "${GREEN}Done!${NC} Run ${YELLOW}source ~/.zshrc${NC} or open a new terminal."
}

case "${1:-}" in
  --uninstall)
    uninstall
    ;;
  --help|-h)
    usage
    ;;
  "")
    install
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    usage
    exit 1
    ;;
esac
