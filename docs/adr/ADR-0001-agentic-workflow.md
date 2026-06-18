# ADR-0001: Adopt the agent-factory agentic workflow

- **Status:** accepted
- **Date:** 2026-06-17
- **Deciders:** paulcullin

## Context

We want to take a product idea and carry it autonomously through:
**idea → PRD/spec → GitHub backlog → parallel implementation in isolated
worktrees → eval/verify against acceptance criteria → merge & cleanup.**

This pattern was proven on **FieldLens** (`paulcullin/fieldlens`), which
established that a small set of conventions makes AFK ("away from keyboard")
agentic development reliable:

- A docs-driven decision trail (running context log + ADRs).
- A pure, testable core.
- A single `npm run check` gate as the sole arbiter of correctness.
- An issue-per-spec backlog with checkbox acceptance criteria.

The question this ADR settles: rather than re-deriving those conventions on
each new project, encode them once as a reusable **template repository** with
Claude Code skills + conventions + CI, so any new project starts pre-wired.

## Decision

We will ship **agent-factory**, a GitHub template repo, whose product is a set
of five composable Claude Code skills plus the surrounding conventions:

- `/spec` — idea → Epic + spec issues with verifiable AC.
- `/implement` — issue → PR in an isolated git worktree.
- `/verify` — PR → AC-graded review (the eval).
- `/ship` — merge an approved, CI-green PR + clean up.
- `/sprint` — orchestrate N issues through the pipeline in parallel.

We bind these together with five **design principles** (carried from FieldLens,
non-negotiable):

1. **One verification gate** — a single `<runner> check` (typecheck + lint +
   test + build) is the sole correctness arbiter.
2. **Acceptance criteria are the spec** — `- [ ]` checkboxes; implement
   satisfies exactly them, verify grades against them. No AC = no work.
3. **Isolation per unit of work** — one worktree + branch per issue.
4. **Docs accumulate** — context log + ADRs are part of every change.
5. **Deterministic before AI** — `check` gates correctness; AI verify gates AC
   *coverage*. AI judgment never replaces the deterministic gate.

## Consequences

- New projects inherit a working AFK pipeline on day one; no per-project
  re-derivation.
- The machinery is **language-agnostic scaffolding** (skills + conventions +
  CI), with `node-ts` as the one worked stack template. Other stacks are
  backlog.
- The skills depend on `gh` (required) and benefit from the GitHub MCP
  (line-level review comments) and a Preview MCP (dynamic smoke tests).
- Risk: parallel agents can integrate two individually-green branches that
  conflict in combination. Mitigation: `/sprint` serializes overlapping issues
  (via `Touches:` hints) and serializes the merge step with a `check` between.

## Alternatives considered

- **Per-project bespoke setup** — rejected: re-deriving conventions each time is
  exactly the cost this template removes.
- **A heavyweight platform / app instead of skills + conventions** — rejected:
  the proven unit of reuse is small, composable skills plus a CLAUDE.md working
  agreement, not application code.
