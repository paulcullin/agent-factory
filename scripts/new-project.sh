#!/usr/bin/env bash
# Stamp a fresh project from this template.
#
# Copies a chosen templates/<stack> into a new directory, inits git, optionally
# creates the GitHub repo, sets up labels, and seeds docs/.
#
# Usage:
#   scripts/new-project.sh <project-name> [--stack node-ts] [--private] [--no-remote]
#
# Requires: git; gh CLI (for repo creation + labels) unless --no-remote.
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "usage: $0 <project-name> [--stack node-ts] [--private] [--no-remote]" >&2
  exit 2
fi
shift

STACK="node-ts"
VISIBILITY="--public"
MAKE_REMOTE=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stack)      STACK="$2"; shift 2 ;;
    --private)    VISIBILITY="--private"; shift ;;
    --public)     VISIBILITY="--public"; shift ;;
    --no-remote)  MAKE_REMOTE=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

SRC="$TEMPLATE_ROOT/templates/$STACK"
if [[ ! -d "$SRC" ]]; then
  echo "no such stack template: templates/$STACK" >&2
  echo "available:" >&2
  ls -1 "$TEMPLATE_ROOT/templates" | sed 's/^/  /' >&2
  exit 1
fi

DEST="$PWD/$NAME"
if [[ -e "$DEST" ]]; then
  echo "destination already exists: $DEST" >&2
  exit 1
fi

echo "==> Stamping '$NAME' from stack '$STACK'"
mkdir -p "$DEST"

# Copy the stack starter.
cp -R "$SRC"/. "$DEST"/

# Copy the shared machinery (skills, CLAUDE.md, github templates, docs scaffold).
cp -R "$TEMPLATE_ROOT/.claude"  "$DEST"/.claude
cp -R "$TEMPLATE_ROOT/.github"  "$DEST"/.github
cp    "$TEMPLATE_ROOT/CLAUDE.md" "$DEST"/CLAUDE.md
mkdir -p "$DEST/docs/adr"
cp "$TEMPLATE_ROOT/docs/00-context.md"        "$DEST/docs/00-context.md"
cp "$TEMPLATE_ROOT/docs/WORKFLOW.md"          "$DEST/docs/WORKFLOW.md"
cp "$TEMPLATE_ROOT/docs/adr/ADR-0000-template.md" "$DEST/docs/adr/ADR-0000-template.md"

# Seed a fresh context-log header.
{
  echo "# $NAME — context log"
  echo
  echo "_Append-only running notes. Newest at the bottom._"
  echo
  echo "## $(date +%Y-%m-%d) — project bootstrapped"
  echo "- Stamped from agent-factory template, stack \`$STACK\`."
} > "$DEST/docs/00-context.md"

cd "$DEST"
git init -q
git add -A
git commit -qm "chore: bootstrap $NAME from agent-factory ($STACK)"
echo "==> git initialized and first commit made"

if [[ "$MAKE_REMOTE" -eq 1 ]] && command -v gh >/dev/null 2>&1; then
  echo "==> creating GitHub repo"
  gh repo create "$NAME" "$VISIBILITY" --source=. --remote=origin --push
  echo "==> setting up labels"
  "$TEMPLATE_ROOT/scripts/setup-labels.sh"
else
  echo "==> skipping remote creation (use 'gh repo create' + scripts/setup-labels.sh later)"
fi

echo "==> Done. Next: cd $NAME && <install deps> && npm run check"
