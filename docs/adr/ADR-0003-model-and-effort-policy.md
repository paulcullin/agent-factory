# ADR-0003: Model and effort policy for the pipeline

- **Status:** accepted
- **Date:** 2026-09-24
- **Deciders:** paulcullin

## Context

`CLAUDE.md` has carried a model and effort policy since the blueprint was
written: medium effort by default, Sonnet 5 for everything, escalate to Opus 4.8
after two failed Sonnet attempts, and a note that intro pricing ended on
2026-08-31. Three of those four statements are now wrong or stale.

What changed:

- **Opus 5.5 is the current frontier coding model** and is available on paid
  subscription plans including Pro. It is priced below Opus 5 ($4 / $20 per
  million input / output tokens) with cache reads at $0.20 per million, and it
  defaults to `medium` effort rather than `high`. Opus 4.8 is no longer the
  escalation target.
- **Effort is a first-class control in Claude Code**, set by `/effort`,
  `--effort`, `effortLevel`, and per-model `modelSettings`, with `low`,
  `medium`, `high`, `xhigh`, and `max` available on the current models, and
  `maxEffortLevel` available as a cap. The repo's `.claude/settings.json`
  carried a top-level `effort` key, which is not one of the documented settings.
- **Anthropic has published measured guidance** on what drives the cost of an
  agentic task: turns, cache reads, output tokens including thinking, and model
  choice, in that order. Two findings bear directly on this pipeline: running a
  backlog at low or medium effort and re-running only the failures at high
  reaches an equal or better pass rate for roughly half the cost of running
  everything high; and changing effort mid-session invalidates the prompt cache,
  which is the largest lever of the four.
- **The adversarial-review rule has a new edge case.** The pipeline pins the
  verifying agent to a different and stronger model than the implementing agent.
  With Opus 5.5 as the strongest model in the palette, a ticket implemented on
  Opus has no stronger verifier available.

## Decision

We will replace the effort policy, model routing, and cost note in `CLAUDE.md`
with a single "Model and effort policy" section plus a "Turn and context
discipline" section, and we will:

- Make Sonnet 5 at `medium` the session default, with Opus 5.5 at `medium`
  reserved for `/spec`, `/verify`, and design-heavy tickets.
- Reserve `high` for a ticket that has already failed twice, or for an
  architecture call being recorded as an ADR, and forbid `xhigh` and `max`
  without a human in the loop.
- Escalate effort only after a failure, never in anticipation of one.
- Route reading work (repository search, log reading, issue reading) to Haiku
  subagents, so only deciding and editing run on the session model.
- State plainly that when Opus implements, verification runs on Sonnet at `high`
  or on the deterministic gate plus human review, and that the review body must
  say which.
- Replace the unsupported top-level `effort` key in `.claude/settings.json` with
  `effortLevel`, per-model `modelSettings`, `maxEffortLevel: "high"`, and
  `CLAUDE_CODE_SUBAGENT_MODEL=haiku`.
- Keep model names out of the skills themselves. The skills reference the policy
  in `CLAUDE.md`; only `CLAUDE.md` and `.claude/settings.json` name models, so
  the next model release is a two-file change.

## Consequences

**Easier.** A project stamped from this template now starts on the cheaper model
by default, which matters most to a subscription user working against rolling
session limits and weekly caps. The escalation ladder is written down, so an
unattended sprint cannot quietly run the whole backlog at high effort. Effort is
set through documented settings keys, so it actually applies.

**Harder.** Two models in one pipeline means the verify step has to know what
implemented the code, and a session that switches models mid-flight loses cached
context. The independence caveat is now a documented limitation rather than an
unstated assumption, which is more honest and slightly less tidy.

**Follow-ups.** Model names and prices go stale; this ADR is the record of the
reasoning, not of the model list. Re-run an effort sweep on a real backlog
rather than trusting these defaults, and record the result in
`docs/00-context.md`. Anthropic's own advice is that your own numbers are the
ones to trust.

## Alternatives considered

- **Opus 5.5 as the session default.** Simplest, and the best quality per
  ticket. Rejected for subscription users: a mechanical ticket does not need it,
  and the weekly cap is the binding constraint, not the per-token price.
- **`opusplan` (Opus plans, Sonnet executes) as the default.** Attractive, and
  close to what this policy does by hand. Kept as a documented option rather
  than the default, because the split here is per ticket rather than per phase,
  and because a plan-mode boundary does not map cleanly onto the five skills.
- **Adding Fable as the escalation target above Opus.** Rejected: it is not
  included in subscription usage the way Opus is, so making it part of the
  default pipeline would push a stamped project toward paid usage credits
  without the user choosing that.
- **Leaving the policy alone and documenting the drift in README.** Rejected;
  the whole point of a working agreement the agents read is that it is current.
