#!/usr/bin/env bash
# Idempotently create the backlog labels the agentic workflow expects.
# Usage: scripts/setup-labels.sh [owner/repo]
# Requires: gh CLI, authenticated.
set -euo pipefail

REPO_ARG=()
if [[ "${1:-}" != "" ]]; then
  REPO_ARG=(--repo "$1")
fi

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
echo "Done."
