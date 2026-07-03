# CLAUDE.md — Agentic Working Agreement

This file is the contract every Claude Code session (interactive or AFK) works
under in this repository. It is loaded automatically. Read it before acting.

> This is the **agent-factory** template repo itself. When a new project is
> stamped from this template, this file ships with it and the project-specific
> sections below (Architecture map, Gotchas, Commands runner) get filled in.

## Effort policy
- Medium by default.
- High only for: hard debugging, multi-file refactors,
  architecture calls.
- Low for: formatting, renames, boilerplate.

## Model routing
- Default to Sonnet 5 for everything.
- Escalate to Opus 4.8 only after two failed Sonnet attempts,
  or for the deepest reasoning tasks.

## Cost note
- Intro pricing ($2/$10) ends Aug 31, 2026. Run large batch
  jobs before then where possible.

## Commands

- `<runner> check` — the **single verification gate** (typecheck + lint + test
  + build). It is the sole arbiter of "is this change safe." Run it before
  declaring any change done. For the `node-ts` stack this is `npm run check`.

> Replace `<runner>` with the concrete command when stamping a project
> (e.g. `npm run check`, `pnpm check`, `make check`, `cargo check && cargo test`).

## Issue tracker

- `issue_tracker` — which backlog the five skills read from and write to.
  Allowed values: `github` (default) or `jira`.

> Set `issue_tracker` when stamping or adopting a project. Leave it as
> `github` unless the project's backlog lives in Jira.

- When `issue_tracker: jira`, also set:
  - `jira_site` — the Atlassian Cloud site URL (e.g. `https://yourteam.atlassian.net`).
  - `jira_project_key` — the Jira project key issues are filed under (e.g. `PROJ`).

## Agentic mode

- The acceptance criteria in a worked issue **ARE** the spec. Implement exactly
  those — no more, no less. Each criterion maps to a code change or a test.
- Loop: implement → `check` → fix → `check`. **Max 5 iterations**, then surface
  a blocker (comment on the issue) instead of thrashing.
- **One worktree + branch per issue.** Never work across issues in one branch.
- **Never force-push.** Never merge without `check` green **AND** a verify
  approval.
- If AC is ambiguous, **comment on the issue and stop**. Do not guess scope.
- Never touch files outside the issue's scope.

## Conventions

- Tests colocated with modules; new core logic requires tests.
- Keep a pure, testable core; push side effects to the edges.
- Docs are part of the change, never an afterthought:
  - Decisions → `docs/adr/` (one ADR per non-trivial choice).
  - Running notes → `docs/00-context.md` (**append-only** log).
- Scope comes from issues; the checkbox AC is the source of truth.
- Deterministic before AI: `check` gates correctness; AI verify gates
  *coverage* of the AC. Never let AI judgment replace the deterministic gate.
- **GitHub access: prefer the GitHub MCP, fall back to `gh`.** When the GitHub
  MCP is available, use it for richer/structured operations — above all the
  **line-level inline review comments** in `/verify`, which `gh` can't place
  well. When it isn't, every operation must still work via the `gh` CLI, which
  is the required baseline. `gh` is also the *only* option in non-agent contexts
  (the `scripts/` helpers and CI), so skills keep their `gh` form as the
  portable default. Never make a skill hard-depend on an MCP server.
- **Exception — Jira mode hard-depends on the Atlassian MCP.** When
  `issue_tracker: jira`, the Atlassian MCP server is a **required** dependency
  for the skills' Jira-backed code paths, with **no CLI fallback**. This is a
  deliberate exception to the "never hard-depend on an MCP server" rule above:
  unlike GitHub, Jira has no CLI as ubiquitous or as reliable as `gh` to fall
  back to, so there is no portable baseline to keep working without the MCP.
  This exception is scoped to `jira` mode only — `github` mode keeps the
  `gh`-fallback guarantee unchanged.

## The pipeline (skills)

| Skill | Trigger | Does |
|---|---|---|
| `/spec <idea>` | "spec this", "write a PRD", "break into issues" | idea → Epic + spec issues with AC |
| `/implement <#>` | "implement #N", "pick up next backlog item" | issue → PR in an isolated worktree |
| `/verify <#>` | "verify PR N", "review this PR" | PR → AC-graded review |
| `/ship <#>` | "ship PR N", "merge it" | merge + worktree cleanup |
| `/sprint [N]` | "run the sprint", "work the backlog" | orchestrate N issues in parallel |

See `docs/WORKFLOW.md` for the end-to-end human guide.

---

## Architecture map — TODO (fill in when stamping a project)

<!-- Describe the top-level modules, where the pure core lives, where side
     effects live, and the data flow. Keep it to a screenful. -->

- Core: `TODO`
- Edges / IO: `TODO`
- Entry point: `TODO`

## Gotchas — TODO (fill in when stamping a project)

<!-- Project-specific traps. Seeded with one known cross-project gotcha. -->

- Pushing a `.github/workflows/*.yml` file requires the `workflow` token scope:
  run `gh auth refresh -s workflow` if a push is rejected with a workflow-scope
  error. (Hit during FieldLens bootstrap.)
- **PR self-approval is blocked.** If `/verify` runs under the same `gh`
  identity that authored the PR (the default single-account setup), `gh pr
  review --approve` always fails with `Can not approve your own pull
  request` — GitHub blocks this by identity, not by review content. `/verify`
  skips attempting `--approve` in that case and posts the AC grade via `gh pr
  comment` instead; a human must then manually approve before `/ship`'s guard
  (which requires an approving review) will pass. (Hit verifying PR #13.)
- `TODO`
