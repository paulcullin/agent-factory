# ADR-0003: Harden /sprint for autonomous, unattended operation

- **Status:** accepted
- **Date:** 2026-08-15
- **Deciders:** paulcullin

## Context

Every safeguard `/sprint` has today is scoped to one issue: `/implement`'s
5-iteration `check` cap, one worktree per issue, serialized merges. `/sprint`
itself only runs when a human types it — there is no notion of a run that
keeps going on its own, and so nothing has needed to answer: what stops a
*run* (not just one issue) from going wrong? What happens if a run is
interrupted mid-issue? How does an operator halt a loop that's already
running unattended? How does a transient `gh`/MCP failure get told apart from
a real blocker?

These questions matter now because the point of `/sprint` — orchestrating the
backlog without a human driving each step — is only half-realized while a
human still has to be the one to invoke it. Wiring it to a recurring
scheduled trigger closes that gap, but only safely if `/sprint` itself carries
the safeguards a genuinely unattended loop needs: a run-level circuit
breaker, resumability across interruptions, a documented kill switch, and
backoff on transient infrastructure failures. Standard practice for any
autonomous/agentic loop — bounded blast radius, a way to stop it, and a way
to resume cleanly — currently exists here only at the single-issue grain.

One related gap is explicitly out of scope: `/ship` cannot self-approve a PR
under a single `gh` identity (documented in `CLAUDE.md` → Gotchas), so a
fully unattended run still needs a human for that one step. Closing that gap
means a second bot identity or a policy decision — a bigger call than
hardening the loop mechanics, and not blocking on it: the safeguards below
are valuable regardless of how that gap eventually closes.

## Decision

We will harden `/sprint` (and, where the fix belongs there instead,
`/implement`) with four run-level safeguards, tracked as spec issues under
epic #19:

- **Circuit breaker** (#20) — a run stops picking up new issues after 3
  consecutive blocked/failed issues, and respects a per-run cap on total
  issues attempted, independent of the existing per-issue 5-iteration cap.
- **Resumability** (#21) — before spawning a fresh `implement` sub-agent,
  `/sprint` checks for an existing worktree/branch for that issue and resumes
  it instead of restarting from scratch; the 5-iteration cap is tracked
  across resumes so it can't silently reset.
- **Kill switch** (#22) — `/sprint` checks for a `.claude/STOP` marker file
  between issues (never mid-issue) and halts cleanly if present;
  `docs/WORKFLOW.md` documents this alongside disabling the scheduling
  trigger as the two ways to halt an unattended run.
- **Backoff on transient failures** (#23) — transient `gh`/MCP failures
  (rate limits, timeouts) get retried with exponential backoff; real blockers
  (failing AC, CI red, ambiguous scope) are never retried, unchanged from
  today.

A fifth issue (#24) documents how to actually wire `/sprint` to a recurring
scheduled trigger, once the above safeguards make that safe to do — this is
the "turn the crank" step, deliberately kept as documentation rather than new
agent-factory machinery (see Alternatives).

## Consequences

- `/sprint` becomes safe to point at a recurring trigger and leave running,
  which is the actual point of an orchestrator skill — closing the gap
  between "orchestrates the backlog" and "orchestrates the backlog without a
  human kicking off each run."
- Existing per-issue invariants (5-iteration cap, one worktree per issue,
  never force-push, serialized merges) are unchanged; the new safeguards are
  additive at the run level, not a replacement.
- New failure mode to watch: the circuit breaker's blocked-issue counter and
  the resumability check both need to correctly distinguish "this issue is
  genuinely blocked" from "this issue's worktree just hasn't been touched
  yet" — get that wrong and a run either stops too eagerly or resumes stale
  state. Each issue's AC calls out the specific state each check reads.
- The `/ship` self-approval gap remains a real ceiling on full autonomy:
  every run under a single `gh` identity still needs a human to approve
  before merge. #24's docs say so explicitly rather than let anyone build a
  scheduling setup on the mistaken assumption that `/sprint` will merge
  without them.

## Alternatives considered

- **Build a bespoke scheduler inside agent-factory** — rejected: this repo's
  product is skills + conventions, not application code (see ADR-0001). The
  actual clock is infrastructure that already exists outside agent-factory
  (a Routine/cron trigger, or an equivalent scheduling mechanism); agent-
  factory's job is making `/sprint` safe to point it at, not reimplementing
  it.
- **Skip the circuit breaker and rely solely on the per-issue 5-iteration
  cap** — rejected: that cap bounds one issue thrashing against `check`, not
  a run that keeps discovering new blocked issues and burning through the
  backlog. An unattended loop needs a stop condition scoped to the run, not
  just the unit of work.
- **Close the `/ship` self-approval gap as part of this epic** — rejected for
  now: it requires either a second bot identity or a deliberate policy
  decision to relax the approval guard, both bigger and riskier calls than
  hardening loop mechanics. Left as an explicit non-goal and documented as a
  known limitation instead of quietly working around it.
