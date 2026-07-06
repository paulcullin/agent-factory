#!/usr/bin/env bash
# Idempotently create the backlog labels the agentic workflow expects.
# Usage: scripts/setup-labels.sh [owner/repo] [pkg-label]
#
#   pkg-label   optional; also creates/updates this label (e.g. "pkg:foo") for
#               scoping a shared tracker to one package in a monorepo — see
#               CLAUDE.md -> Monorepo scope and the /onboard skill.
# Requires: gh CLI, authenticated.
set -euo pipefail

REPO_ARG=()
if [[ "${1:-}" != "" ]]; then
  REPO_ARG=(--repo "$1")
fi
PKG_LABEL="${2:-}"

create_label() {
  local name="$1" color="$2" desc="$3"
  # --force makes this idempotent: creates or updates.
  gh label create "$name" --color "$color" --description "$desc" --force "${REPO_ARG[@]}"
  echo "  ✓ $name"
}

echo "Setting up backlog labels..."
create_label "epic"    "5319e7" "A theme grouping several spec issues"
create_label "spec"    "1d76db" "A single unit of work, one PR, with acceptance criteria"
create_label "backlog" "c2e0c6" "Queued work not yet picked up"

if [[ -n "$PKG_LABEL" ]]; then
  create_label "$PKG_LABEL" "bfd4f2" "Scopes issues/PRs to one package in this monorepo"
fi
echo "Done."
