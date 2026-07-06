# ADR-0002: Interview-driven onboarding, and scope-to-one-package for monorepos

- **Status:** accepted
- **Date:** 2026-07-06
- **Deciders:** paulcullin

## Context

`scripts/adopt.sh` (see ADR-0001) lands the agent-factory machinery into an
existing project non-destructively, and `docs/ADOPTING.md` documents the
follow-up: merge `CLAUDE.md` by hand, wire the real `check` gate, set up
labels, optionally switch to Jira. That follow-up assumed a single-package
repo and required the human to do the actual thinking — reading their own
tooling, composing a check command, filling in the Architecture map — with
only a checklist to guide them.

This surfaced concretely when adopting into an existing **monorepo** with its
own conventions, an established architecture, and a live Jira board: the
manual merge steps didn't say what to do about a check gate that has to be
package-scoped, or about a shared issue tracker that now needs to hold issues
for more than one package without them colliding.

## Decision

We will ship a sixth skill, **`/onboard`**, and one new `CLAUDE.md` section,
**Monorepo scope**:

- `/onboard` is a conversational, interview-driven finish-the-adoption skill
  (not a shell `--interactive` script) so it can *read* the project — workspace
  tooling, `package.json` scripts, README/CONTRIBUTING, any existing
  `CLAUDE.md` — and infer answers instead of only asking. It writes the merged
  `CLAUDE.md` (Commands/check gate, Architecture map, Gotchas, Issue tracker,
  Monorepo scope), wires labels or Jira config, and logs the decision — the
  automated equivalent of `docs/ADOPTING.md`'s manual steps 1-4.
- `CLAUDE.md` gains a **Monorepo scope** section (`monorepo`, `package_path`,
  `package_label`), defaulting to a no-op (`monorepo: false`) so it doesn't
  affect any existing single-package adoption.
- For monorepos, the workflow **scopes to one package**, not the whole repo:
  its own `check` gate, its own worktree/PR boundary, its own nested
  `<package_path>/CLAUDE.md` that composes with (rather than replaces) the
  repo root's own conventions. `/spec`, `/implement`, and `/sprint` get small,
  additive forks — mirroring the existing `issue_tracker: github`/`jira`
  fork — to stay inside that boundary and to filter a shared, repo-wide
  tracker down to the scoped package via a `package_label` (GitHub) or a
  `Package: <package_path>` line (Jira, which has no native cross-project
  label to reuse here).
- `/onboard` is re-runnable: onboarding a second package in the same monorepo
  later is just running it again from inside that package's directory.

## Consequences

- Adoption into a real, already-conventioned project (including monorepos)
  goes from "read a doc, merge files by hand" to "run one skill, answer what
  it can't infer." The quality of the wired `CLAUDE.md` stops depending on how
  carefully a human followed a checklist.
- `spec`/`implement`/`sprint` carry one more optional fork (Monorepo scope),
  additive and off by default — no behavior change for existing
  single-package adoptions.
- New risk: a shared GitHub/Jira tracker now needs consistent package
  labeling/tagging across `/spec`, `/sprint`, and `/onboard`'s
  `scripts/setup-labels.sh` call, or issue selection silently drifts across
  package boundaries. Mitigated by having all three go through the same
  `package_label` / `Package:` convention defined once in `CLAUDE.md`.
- `verify` and `ship` needed no changes — they already operate generically off
  issue/PR content, so package scoping is invisible to them.

## Alternatives considered

- **A `scripts/adopt.sh --interactive` shell prompt flow** — rejected: plain
  `read -p` prompts can ask but can't reason about the repo's existing files,
  so every answer would have to come from the human even when it's plainly
  inferable (e.g. an existing `check` script, a `turbo.json` filter target).
  The interview is inherently conversational; a skill fits it better than a
  script.
- **Scope agent-factory to the whole monorepo** — rejected for this adoption:
  a single check gate across every package in a large existing monorepo
  doesn't match "one worktree per issue" cleanly, and AC/PR scope would blur
  across unrelated packages. Scoping to one package keeps the blast radius and
  the acceptance-criteria boundary exactly as tight as the rest of this
  workflow already assumes. (Whole-repo scope remains possible — just set
  `monorepo: false` and treat the root as the one package — for monorepos
  that genuinely build/test/release as a single unit.)
- **Bake monorepo scope directly into `adopt.sh`** — rejected: `adopt.sh`'s
  value is being purely mechanical and non-interactive (safe to run
  unattended). Scope selection, check-gate composition, and tracker config are
  all judgment calls that need a conversation, which belongs in `/onboard`,
  not in a script.
