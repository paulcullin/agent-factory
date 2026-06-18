# CLAUDE.md — Agentic Working Agreement

This file is the contract every Claude Code session (interactive or AFK) works
under in this repository. It is loaded automatically. Read it before acting.

> This is the **agent-factory** template repo itself. When a new project is
> stamped from this template, this file ships with it and the project-specific
> sections below (Architecture map, Gotchas, Commands runner) get filled in.

## Commands

- `<runner> check` — the **single verification gate** (typecheck + lint + test
  + build). It is the sole arbiter of "is this change safe." Run it before
  declaring any change done. For the `node-ts` stack this is `npm run check`.

> Replace `<runner>` with the concrete command when stamping a project
> (e.g. `npm run check`, `pnpm check`, `make check`, `cargo check && cargo test`).

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
- `TODO`
