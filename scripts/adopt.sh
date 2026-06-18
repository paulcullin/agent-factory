#!/usr/bin/env bash
# Adopt the agent-factory workflow into an EXISTING project.
#
# Where new-project.sh stamps a fresh repo, this drops the shared machinery —
# the five skills, the agentic working agreement, issue/PR templates, and the
# workflow docs — into a project you already have.
#
# It is NON-DESTRUCTIVE: it never overwrites a file you already have. Where a
# merge is needed (CLAUDE.md, .claude/settings.json) it writes a *.agent-factory
# reference copy alongside yours instead of clobbering. Everything it adds or
# skips is printed so you can finish any merges by hand.
#
# It does NOT touch git history, your CI, or create a remote — your repo and
# pipeline already exist.
#
# Usage (from the target project root):
#   /path/to/agent-factory/scripts/adopt.sh
# or point it at a project:
#   scripts/adopt.sh /path/to/your/project [--labels]
#
#   --labels   also run setup-labels.sh against the target's GitHub remote
#              (needs gh, authenticated). Off by default to avoid surprise
#              network calls.
#
# Requires: git. gh CLI only if --labels.
set -euo pipefail

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET="$PWD"
DO_LABELS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --labels) DO_LABELS=1; shift ;;
    -* ) echo "unknown flag: $1" >&2; exit 2 ;;
    *  ) TARGET="$(cd "$1" && pwd)"; shift ;;
  esac
done

if [[ "$TARGET" -ef "$TEMPLATE_ROOT" ]]; then
  echo "Refusing to adopt into the agent-factory template itself." >&2
  exit 1
fi
if [[ ! -d "$TARGET/.git" ]] && ! git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Warning: $TARGET is not a git repo. Adoption assumes an existing project." >&2
fi

echo "==> Adopting agent-factory into: $TARGET"

rel() { printf '%s' "${1#"$TARGET"/}"; }
log_add()  { printf '  + %s\n'                      "$(rel "$1")"; }
log_skip() { printf '  - exists, skipped: %s\n'     "$(rel "$1")"; }
log_ref()  { printf '  ~ exists; wrote reference: %s\n' "$(rel "$1")"; }

# Copy src -> dst only if dst is absent.
copy_if_absent() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then log_skip "$dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  log_add "$dst"
}

# Copy src -> dst; if dst exists, leave it and drop a reference copy beside it.
copy_or_reference() {
  local src="$1" dst="$2" ref="$3"
  if [[ -e "$dst" ]]; then
    cp "$src" "$ref"
    log_ref "$ref"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log_add "$dst"
  fi
}

echo "-- skills (the product) --"
for skill in "$TEMPLATE_ROOT"/.claude/skills/*/; do
  name="$(basename "$skill")"
  copy_if_absent "$skill" "$TARGET/.claude/skills/$name"
done

echo "-- permissions allowlist --"
copy_or_reference \
  "$TEMPLATE_ROOT/.claude/settings.json" \
  "$TARGET/.claude/settings.json" \
  "$TARGET/.claude/settings.agent-factory.json"

echo "-- working agreement --"
copy_or_reference \
  "$TEMPLATE_ROOT/CLAUDE.md" \
  "$TARGET/CLAUDE.md" \
  "$TARGET/CLAUDE.agent-factory.md"

echo "-- issue + PR templates --"
copy_if_absent "$TEMPLATE_ROOT/.github/ISSUE_TEMPLATE/epic.md" "$TARGET/.github/ISSUE_TEMPLATE/epic.md"
copy_if_absent "$TEMPLATE_ROOT/.github/ISSUE_TEMPLATE/spec.md" "$TARGET/.github/ISSUE_TEMPLATE/spec.md"
copy_if_absent "$TEMPLATE_ROOT/.github/PULL_REQUEST_TEMPLATE.md" "$TARGET/.github/PULL_REQUEST_TEMPLATE.md"

echo "-- workflow docs --"
copy_if_absent "$TEMPLATE_ROOT/docs/WORKFLOW.md" "$TARGET/docs/WORKFLOW.md"
copy_if_absent "$TEMPLATE_ROOT/docs/ADOPTING.md" "$TARGET/docs/ADOPTING.md"
copy_if_absent "$TEMPLATE_ROOT/docs/adr/ADR-0000-template.md" "$TARGET/docs/adr/ADR-0000-template.md"
if [[ ! -e "$TARGET/docs/00-context.md" ]]; then
  mkdir -p "$TARGET/docs"
  {
    echo "# $(basename "$TARGET") — context log"
    echo
    echo "_Append-only running notes. Newest at the bottom._"
    echo
    echo "## $(date +%Y-%m-%d) — adopted agent-factory workflow"
    echo "- Brought in the skills, working agreement, and templates via adopt.sh."
  } > "$TARGET/docs/00-context.md"
  log_add "$TARGET/docs/00-context.md"
else
  log_skip "$TARGET/docs/00-context.md"
fi

if [[ "$DO_LABELS" -eq 1 ]]; then
  echo "-- labels --"
  "$TEMPLATE_ROOT/scripts/setup-labels.sh"
fi

cat <<'NEXT'

==> Adopted. Finish wiring it up:

  1. CLAUDE.md — if a CLAUDE.agent-factory.md was written, merge its
     Commands / Agentic mode / Conventions sections into your existing
     CLAUDE.md. Set <runner> check to your project's real gate command.
  2. The single gate — make sure ONE command runs typecheck + lint + test +
     build, and that your CI runs that same command. See the template's
     .github/workflows/ci.yml for a reference (do not blind-copy it; adapt to
     your stack).
  3. Labels — run scripts/setup-labels.sh (or re-run with --labels) so the
     epic/spec/backlog labels exist on your remote.
  4. Restart Claude Code in the project so it discovers the new skills, then
     try: /spec <an idea>.

See docs/ADOPTING.md for the full guide.
NEXT
