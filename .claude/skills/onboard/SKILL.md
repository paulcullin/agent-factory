---
name: onboard
description: Interview-driven finish-the-adoption skill. After scripts/adopt.sh has landed the skills into an existing project, /onboard infers what it can from the repo (workspace tooling, package.json scripts, README/CONTRIBUTING, any existing CLAUDE.md) and asks only what it can't, then writes the wired CLAUDE.md (check gate, architecture map, gotchas, issue tracker, and — for monorepos — the Monorepo scope section), sets up labels, and logs the decision. Use when the user says "onboard this project", "finish adopting agent-factory", "wire up the check gate", or naturally right after running adopt.sh. Re-runnable inside an already-adopted monorepo to onboard another package.
---

# /onboard — finish wiring agent-factory into a real project

`scripts/adopt.sh` is mechanical: it lands files non-destructively and stops.
`/onboard` is the thinking layer on top of it — it reads the project, infers
as much as it safely can, asks only what it can't infer, and writes the
result. This replaces the manual "merge CLAUDE.md by hand" steps in
`docs/ADOPTING.md`.

`/onboard` is a **one-time bootstrap skill**, not part of the per-issue
pipeline (`/spec` → `/implement` → `/verify` → `/ship` → `/sprint`). It's
re-runnable — once per package if the project is a monorepo with more than one
package to onboard.

## Procedure

### 1. Locate context

- Resolve the git root (`git rev-parse --show-toplevel`).
- Check whether `CLAUDE.md` already exists at the root, and whether a
  `CLAUDE.agent-factory.md` reference copy sits beside it (the signature
  `adopt.sh` leaves when it found an existing `CLAUDE.md` it wouldn't
  overwrite). Read both if present — the reference copy carries the template's
  Commands / Agentic mode / Conventions sections verbatim.
- If neither `.claude/skills/` nor this skill itself could plausibly be
  running, something's wrong — but in practice, if `/onboard` triggered at
  all, `adopt.sh` (or `new-project.sh`) has already run. If you find no
  `.claude/skills/` directory at all, stop and tell the user to run
  `scripts/adopt.sh` first rather than trying to reproduce its file-landing
  logic here.
- Determine whether the **current working directory looks like a package
  inside a monorepo**: it isn't the git root, and it has its own manifest
  (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, ...). If so,
  propose `package_path` = the path from git root to cwd. If cwd *is* the git
  root, ask whether this project is a monorepo at all before assuming
  whole-repo scope.

### 2. Detect and propose (read-only — no writes yet)

- **Monorepo tooling.** Look for `pnpm-workspace.yaml`, `turbo.json`,
  `nx.json`, `lerna.json`, a `workspaces` field in the root `package.json`, a
  Cargo `[workspace]`, or a `go.work`. This tells you what filter syntax is
  available (e.g. `turbo run check --filter=<pkg>`, `pnpm --filter <pkg>
  check`, `nx run <pkg>:check`).
- **The check gate.** Read the scoped package's own manifest for
  lint/typecheck/test/build scripts (or equivalents for non-Node stacks).
  Compose one candidate `<runner> check` command:
  - If the package already has its own `check` script, use it verbatim.
  - Else if a monorepo tool with per-package filtering was detected, propose
    the filtered form, **and** propose adding a package-local `check` script
    that chains whatever lint/typecheck/test/build scripts already exist —
    show both the addition and the resulting `<runner> check` value.
  - Else compose a plain chained command directly from what's there (e.g.
    `npm run typecheck && npm run lint && npm test && npm run build`).
  - This is a **proposal only** — never write it without confirmation (step
    3).
- **Architecture map.** From the scoped package's source layout and its
  manifest's entry point (`main`/`exports`/`bin`), propose a Core / Edges-IO /
  Entry point sketch. Look for conventional names (`core`, `domain`, `lib` vs.
  `adapters`, `handlers`, `routes`, `cli`) but don't force a shape that isn't
  there — it's fine to say "no clear core/edge split observed" if true.
- **Tracker signals.** Skim `README.md`, `CONTRIBUTING.md`, and any existing
  `CLAUDE.md` for mentions of Jira (a site URL, a project key like `PROJ-123`
  patterns, or explicit statements of where the backlog lives).

### 3. Interview

Batch these with `AskUserQuestion`. Skip any question you inferred with high
confidence in step 2 — show the inferred value instead and only ask if it's
genuinely ambiguous or the signal was weak.

- Confirm the package scope path (or confirm "whole repo, not a monorepo").
- Confirm or edit the proposed `<runner> check` command.
- `issue_tracker`: `github` (default) or `jira`. If `jira`: `jira_site` and
  `jira_project_key` — offer inferred guesses from step 2 if found, otherwise
  ask directly. Never invent these values.
- (GitHub mode only, monorepo case) `package_label` name — propose
  `pkg:<name>` from the package manifest's `name` field, confirm.
- Confirm or correct the proposed Architecture map.
- One open-ended, optional question: "Any known gotchas or tribal knowledge to
  seed (auth quirks, flaky tests, deploy steps, things that have bitten
  people)?"

### 4. Write the wired CLAUDE.md

- **Monorepo, package-scoped:** write a **nested**
  `<package_path>/CLAUDE.md`. Claude Code loads directory-local `CLAUDE.md`
  files for work done under that path, so this composes with (does not
  replace) any repo-root `CLAUDE.md` that already encodes the monorepo's own
  conventions. Contents:
  - A one-line header noting it's package-scoped and composes with the repo
    root's `CLAUDE.md`.
  - `## Commands` — the confirmed `<runner> check`.
  - `## Agentic mode` and `## Conventions` — copied verbatim from the
    template's `CLAUDE.md` (or the `CLAUDE.agent-factory.md` reference copy if
    present) — these are project-invariant.
  - `## Issue tracker` — the confirmed mode and any Jira fields.
  - `## Monorepo scope` — `monorepo: true`, the confirmed `package_path`, and
    `package_label` (github mode).
  - `## Architecture map` and `## Gotchas` — filled from step 3, not left as
    `TODO`.
- **Not a monorepo (whole-repo scope):** merge directly into the root
  `CLAUDE.md` — this is what `docs/ADOPTING.md` currently asks a human to do
  by hand. Fold the reference copy's Commands / Agentic mode / Conventions in,
  fill Architecture map / Gotchas / Issue tracker from the interview, then
  delete the now-redundant `CLAUDE.agent-factory.md`.
- **Never overwrite an existing `CLAUDE.md` outright.** Always compose or
  merge — matching `adopt.sh`'s non-destructive stance.

### 5. Labels / tracker wiring

- `github` mode: run `scripts/setup-labels.sh` — pass the confirmed
  `package_label` as its second argument when monorepo scope is set, so
  `epic`/`spec`/`backlog` and the package label are created together.
- `jira` mode: no label script. Instead, do a read-only confirmation that the
  Atlassian MCP is reachable — discover its tools via `ToolSearch` — and that
  `jira_project_key` resolves. If the MCP isn't connected, **warn, don't
  fail**: `/spec`/`/implement`/`/verify`/`/ship` hard-depend on it in `jira`
  mode (see `CLAUDE.md` → Conventions), so flag it clearly as a blocker to
  resolve before running those.

### 6. Log the decision

Append one entry to the repo-root `docs/00-context.md` (append-only): what was
onboarded (package path or whole-repo), the check command and where it came
from (existing script vs. composed), the tracker mode, and the date. If this
project didn't have an ADR trail yet, point at `docs/adr/ADR-0000-template.md`
and suggest — don't force — writing one.

### 7. Summarize and hand off

Report what was written or created (file paths), any read-only warnings (e.g.
Atlassian MCP not connected), and the next steps:
- **Restart Claude Code** in the project so the nested/updated `CLAUDE.md`
  and skills are (re-)discovered.
- Suggest `/spec <idea>` as the first real command, scoped to the package.
- If this is a monorepo with more packages to bring in later, mention that
  `/onboard` is re-runnable from inside another package directory.

## Invariants (do not violate)

- Never overwrite an existing `CLAUDE.md` outright — compose or merge.
- Never write the `<runner> check` command without explicit user confirmation
  — a wrong gate silently breaks every downstream skill.
- Never invent `jira_site` or `jira_project_key` — ask if the repo doesn't
  clearly evidence them.
- If `adopt.sh` hasn't run yet (no `.claude/skills/` present at all), say so
  and stop rather than re-implementing its file-landing logic.
- Don't force an Architecture map shape that isn't actually there — an honest
  "no clear core/edge split" beats a fabricated one.
