#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DST="$HOME/.claude/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

usage() {
  echo "Usage: $0 [--uninstall] [--target <path>]"
  echo
  echo "Options:"
  echo "  --uninstall     Remove installed skill symlinks"
  echo "  --target <path> Install to a specific directory (default: ~/.claude/skills)"
  echo "  --help          Show this help"
}

uninstall=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall)
      uninstall=true
      shift
      ;;
    --target)
      SKILLS_DST="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      exit 1
      ;;
  esac
done

if [ ! -d "$SKILLS_SRC" ]; then
  echo -e "${RED}Error: skills/ directory not found at $SKILLS_SRC${NC}"
  exit 1
fi

# Collect skill names
skills=()
for skill_dir in "$SKILLS_SRC"/*/; do
  [ -d "$skill_dir" ] || continue
  skills+=("$(basename "$skill_dir")")
done

if [ ${#skills[@]} -eq 0 ]; then
  echo -e "${RED}No skills found in $SKILLS_SRC${NC}"
  exit 1
fi

# Uninstall
if $uninstall; then
  echo "Removing skills from $SKILLS_DST ..."
  removed=0
  for name in "${skills[@]}"; do
    target="$SKILLS_DST/$name"
    if [ -L "$target" ] || [ -e "$target" ]; then
      rm -rf "$target"
      echo -e "  ${RED}removed${NC} $name"
      ((removed++))
    fi
  done
  if [ $removed -eq 0 ]; then
    echo -e "${YELLOW}Nothing to remove.${NC}"
  else
    echo -e "${GREEN}Uninstalled $removed skill(s).${NC}"
  fi
  exit 0
fi

# Install
mkdir -p "$SKILLS_DST"
echo "Installing skills to $SKILLS_DST ..."

installed=0
for name in "${skills[@]}"; do
  src="$SKILLS_SRC/$name"
  target="$SKILLS_DST/$name"

  if [ -L "$target" ]; then
    existing="$(readlink "$target")"
    if [ "$existing" = "$src" ]; then
      echo -e "  ${YELLOW}skip${NC}     $name (already linked)"
      continue
    fi
    rm "$target"
  elif [ -e "$target" ]; then
    echo -e "  ${YELLOW}skip${NC}     $name (non-symlink exists, remove manually to reinstall)"
    continue
  fi

  ln -s "$src" "$target"
  echo -e "  ${GREEN}linked${NC}   $name"
  ((installed++))
done

echo
echo -e "${GREEN}Done!${NC} $installed skill(s) installed, ${#skills[@]} total."
echo "Restart Claude Code to use the new skills."
