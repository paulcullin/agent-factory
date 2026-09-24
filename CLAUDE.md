# CLAUDE.md — Agentic Working Agreement

This file is the contract every Claude Code session (interactive or AFK) works
under in this repository. It is loaded automatically. Read it before acting.

> This is the **agent-factory** template repo itself. When a new project is
> stamped from this template, this file ships with it and the project-specific
> sections below (Architecture map, Gotchas, Commands runner) get filled in.

## Model and effort policy

Claude Code reads effort from `/effort`, `--effort`, the `effortLevel` setting,
and per-model `modelSettings`. Opus 5.5 defaults to `medium` effort; Sonnet 5
and Haiku 4.5 default to `high`. Set effort explicitly rather than relying on a
model's default.

- **Session default: Sonnet 5 at `medium`.** Raise deliberately, never by habit.
- **Opus 5.5 at `medium`:** `/spec` decomposition, `/verify`, and any ticket
  whose difficulty is design judgment rather than typing.
- **Opus 5.5 at `high`:** only for a ticket that has already failed twice, or an
  architecture call being recorded as an ADR. High effort adds roughly 20K
  thinking tokens across a task, which pays for itself only when it prevents a
  retry loop.
- **Escalate on failure, not in advance.** Run the backlog at `medium`, then
  re-run only what failed at `high`. On public coding benchmarks that pattern
  reaches an equal or better pass rate for about half the cost of running
  everything high.
- **`low`:** formatting, renames, mechanical merges, changelog entries.
- **Subagents:** Haiku for search and log reading, Sonnet for multi-file
  reading. Only the agent that edits code runs on the session model.
- **No `xhigh`, no `max`** unless a human chooses it in the moment;
  `maxEffortLevel` in `.claude/settings.json` is the guard.
- **Hold effort constant inside a session.** Changing effort invalidates the
  prompt cache, and cache reads are the largest single cost lever in an agent
  loop.

> **Adversarial review, stated honestly.** The pipeline's rule is that the
> verifying agent runs on a different model from the implementing agent. That
> holds when Sonnet implements and Opus verifies. When Opus implements, there is
> no stronger model in the palette, so verification falls back to Sonnet at
> `high` (independent family, less capable) or to the deterministic gate plus
> human review. Record which one was used; do not claim independence you did not
> have.

## Turn and context discipline

Every turn resends the whole conversation, so turn count and cache hits dominate
what a task costs.

- Batch file reads and tool calls into one turn rather than one per file.
- Run `check` instead of reasoning about whether the code is right. A failing
  gate is cheaper than a model's opinion.
- `/compact` at milestone boundaries, not mid-ticket.
- One ticket per session and per worktree.
- Keep the top of this file stable: no timestamps, no per-session status lines.
  A volatile prefix invalidates the prompt cache for every later turn.
- Record `/usage` before and after long or unattended sessions in
  `docs/00-context.md`.

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

## Monorepo scope

- `monorepo` — whether this CLAUDE.md is scoped to one package inside a larger
  monorepo. Allowed values: `false` (default) or `true`.
- `package_path` — path from the repo root to the scoped package (e.g.
  `apps/foo`). Only meaningful when `monorepo: true`. All skills treat this as
  the working root for the `check` gate; files outside it are out of scope.
- `package_label` — (GitHub mode only) the label used to scope issue
  selection/creation to this package (e.g. `pkg:foo`), since a shared GitHub
  tracker is repo-wide. In Jira mode, scope is carried in a `Package:
  <package_path>` line in the issue body instead — see `/spec`.

> Set these when onboarding a package inside a monorepo — the `/onboard` skill
> does this interactively. Leave `monorepo: false` for a single-package repo.

## Agentic mode

- The acceptance criteria in a worked issue **ARE** the spec. Implement exactly
  those — no more, no less. Each criterion maps to a code change or a test.
- Loop: implement → `check` → fix → `check`. **Max 5 iterations**, then surface
  a blocker (comment on the issue) instead of thrashing. One re-run of a failed
  ticket at higher effort is allowed before the blocker; a third failure is a
  specification problem, not a model problem, so fix the AC instead.
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

`/onboard` is a sixth, one-time bootstrap skill (not part of the per-issue
pipeline above): after `scripts/adopt.sh` lands the machinery into an existing
project, `/onboard` interviews you to finish wiring `CLAUDE.md` — the real
`check` gate, the architecture map, gotchas, issue tracker, and (for
monorepos) the Monorepo scope section above. Re-run it inside an adopted
monorepo to onboard another package.

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
