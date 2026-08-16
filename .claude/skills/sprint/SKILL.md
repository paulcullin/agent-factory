---
name: sprint
description: Run the agentic backlog — pick the top N open spec issues and drive them through implement, verify, and ship in parallel. Use for "run the sprint", "work the backlog", or "build the next N issues".
---

# /sprint — orchestrator (backlog → parallel agents)

Drive the top N open spec issues through the full pipeline:
`implement → verify → ship`, parallel where safe, serialized where they'd
collide.

## Procedure

1. **Select work.** Forks on `issue_tracker` (see `CLAUDE.md`):
   - `github` (default): `gh issue list --label spec --state open` ordered by
     milestone / priority.
   - `jira`: query `jira_project_key` via the Atlassian MCP (discovered via
     `ToolSearch`) for up to N open Story-type issues — e.g. an equivalent of
     `project = <jira_project_key> AND issuetype = Story AND status = "To
     Do"` — ordered by priority.

   Either way, take up to **N** (default **3**; practical ceiling **~5** —
   beyond that, memory pressure and merge-conflict risk on shared files
   outweigh the parallelism).

   If `CLAUDE.md`'s **Monorepo scope** has `monorepo: true`, filter to this
   package's issues only: `github` mode adds `--label <package_label>` to the
   `gh issue list` call; `jira` mode filters candidates client-side for a
   `Package: <package_path>` line in the description.

   Skip selection entirely if the circuit breaker (step 2) has already
   tripped for this run, or if the kill switch (step 3) finds `.claude/STOP`
   present.

   This step calls `gh`/the Atlassian MCP directly (not via a spawned
   sub-agent) — see **Transient failures vs. blockers** below for how to tell
   a transient failure here apart from a blocker, and the retry behavior that
   applies.

2. **Circuit breaker — run-level safeguard.** Before selecting or spawning any
   new work — including when `/sprint` is re-triggered mid-run and discovers
   issues it hadn't seen before — check two run-scoped counters (both live
   only for the duration of this run; they reset when a new `/sprint`
   invocation starts, never mid-run):
   - **Consecutive blocked/failed.** A running count of how many issues in a
     row landed in the Blocked outcome (step 8). Increment on each Blocked
     outcome; reset to zero on each Shipped outcome. Trip the breaker once
     this hits **3**.
   - **Total attempted this run.** A running count of every issue that has had
     an `implement` sub-agent spawned this run, across every round (including
     re-triggers). Trip the breaker once this hits the per-run cap — default
     **10** — regardless of how many have blocked. This cap is independent of
     `N` from step 1, which only bounds how many issues a single selection
     round picks up, not how many the run attempts in total.

   Once either counter trips the breaker: stop selecting new work (step 1) and
   stop spawning new `implement` sub-agents (step 5) for the rest of the run.
   Issues already in flight (implement/verify/ship in progress) run to
   completion — the breaker blocks new work, it does not abort work already
   underway. Any candidate that was identified but never attempted because the
   breaker had already tripped goes into the Circuit-broken bucket in
   Summarize (step 8), not Blocked.

3. **Kill switch — `.claude/STOP` marker.** Before selecting any new work
   (step 1) and again before spawning each new `implement` sub-agent (step 5)
   — including before the very first issue of the run — check whether a
   `.claude/STOP` file exists at the repo root. If it does, halt cleanly: stop
   selecting new work and stop spawning any further `implement` sub-agents for
   the rest of the run.

   This check happens **only between issues**, at those two checkpoints — it
   never interrupts an issue already in flight. Exactly like the circuit
   breaker in step 2, an issue already in implement/verify/ship runs to
   completion once started; the kill switch only stops *new* work from
   starting. Any issue that was selected in step 1 but never had an
   `implement` sub-agent spawned because `.claude/STOP` was found goes into
   the **Halted** bucket in Summarize (step 8), listed by issue number (or
   Jira key) so a human can see exactly which selected issues were left
   untouched.

   The marker is a manual, human-operated kill switch — distinct from the
   automatic circuit breaker in step 2. It exists for cases like: an operator
   watching an unattended/scheduled run notices a problem and wants the very
   next between-issues checkpoint to stop, without waiting for 3 consecutive
   blocked issues or the total-attempted cap to trip the breaker on its own.
   Remove the file to resume normal selection on the next run.

4. **Detect overlap before parallelizing.** Read each candidate's `Touches:`
   line (and skim its AC). Group issues that touch the same core
   files/modules — those **must be serialized**, not run together. Issues with
   disjoint footprints can run in parallel.

   Reading each candidate's `Touches:`/AC is itself a direct `gh`/MCP call
   (`/sprint` making it, not a spawned sub-agent) — see **Transient failures
   vs. blockers** below for how to tell a transient failure here apart from a
   blocker, and the retry behavior that applies.

5. **Implement in parallel (per group).** Before spawning, re-check the
   circuit breaker (step 2) — if it has tripped, stop spawning and route any
   remaining candidates to Circuit-broken instead. Also re-check the kill
   switch (step 3) — if `.claude/STOP` is present, stop spawning and route any
   remaining candidates to Halted instead. Otherwise, for each independent
   issue:
   - **Check for a resumable worktree/branch first.** Before spawning a fresh
     `implement` sub-agent, check whether a worktree/branch already exists
     for this issue number — `feature/issue-<#>` in `github` mode, or the
     lowercased Jira-key branch (e.g. `feature/proj-101`) in `jira` mode. This
     is the common case when `/sprint` itself is being resumed after an
     interruption: a prior round may have already gotten partway through an
     issue. If a matching worktree/branch exists, **resume** the `implement`
     sub-agent against that existing worktree instead of creating a new one —
     `/implement`'s own "Isolate" step documents how it reuses the existing
     state rather than re-scaffolding. If no matching worktree/branch exists,
     spawn fresh as usual.
   - Spawn (or resume) an `implement` sub-agent:
     - `isolation: "worktree"`
     - `run_in_background: true`

   Each gets its own worktree + branch, loops against `check`, and opens a PR.
   Count the spawn against the run's total-attempted counter (step 2) — a
   resumed issue counts once, at the round it was first attempted; resuming
   it in a later round is a continuation of that same attempt, not a new one,
   so don't increment the counter again for it.

6. **Verify on landing.** As each PR opens, spawn a `verify` sub-agent for it.
   It grades AC + confirms CI + optional smoke test, then approves or requests
   changes. On request-changes, hand back to that issue's `implement` agent for
   another loop (respect the 5-iteration cap, then surface a blocker). An
   issue that ends this run as Blocked updates the consecutive-blocked counter
   from step 2.

7. **Ship — serialized.** Merge approved PRs **one at a time**. After each
   merge, re-run `<runner> check` on `main` before merging the next, so two
   branches that were green in isolation can't land a broken combination.

   Checking CI status and merging (`gh pr checks`, `gh pr merge`, or their MCP
   equivalents) are calls `/sprint` makes directly at this step — see
   **Transient failures vs. blockers** below for how to tell a transient
   failure here apart from a blocker, and the retry behavior that applies. A
   merge conflict surfacing from `gh pr merge` is a blocker, not a transient
   failure — see below.

8. **Summarize.** Report five buckets:
   - **Shipped** — issue # (or Jira key when `issue_tracker: jira`), PR #,
     merge SHA.
   - **Blocked** — issue # (or Jira key), the reason (failing AC, ambiguous
     scope, CI).
   - **Still running** — issue # (or Jira key), current stage.
   - **Circuit-broken** — issue # (or Jira key) for any candidate that was
     never attempted because the breaker (step 2) had already tripped, and
     which trip condition caused it (3 consecutive blocked, or the total-
     attempted cap).
   - **Halted** — issue # (or Jira key) for any candidate that was selected
     but never attempted because the kill switch (step 3) found
     `.claude/STOP` present before it could be spawned.

## Conflict rules (do not violate)

- Never parallelize two issues known to touch the same core files — serialize
  them. Use the `Touches:` hint; when in doubt, serialize.
- Never merge in parallel. Ship is always one-at-a-time with a `check` between.
- Respect each issue's 5-iteration implement cap; escalate as a blocker rather
  than looping forever.
- The run-level circuit breaker (step 2) is independent of, and does not
  replace, each issue's existing 5-iteration `/implement` cap: the 5-iteration
  cap governs one issue's internal implement→check→fix retry loop, while the
  breaker governs whether `/sprint` keeps starting *new* issues at all during
  this run. An issue can exhaust its own 5-iteration cap and land in Blocked
  without ever tripping the breaker; the breaker only trips after 3 such
  issues land in Blocked consecutively, or the total-attempted cap is hit.

## Transient failures vs. blockers

Three steps make `gh`/MCP calls **directly**, rather than delegating them to
a spawned sub-agent: **Select work** (step 1 — listing candidate issues),
**Detect overlap** (step 4 — reading each candidate's `Touches:`/AC), and
**Ship** (step 7 — checking CI status and merging). The other steps that
touch `gh`/MCP (Implement in parallel, Verify on landing) do so by spawning
`implement`/`verify` sub-agents that make their own calls under their own
skills' procedures — this section governs only `/sprint`'s own direct calls,
not those.

At each of those three steps, tell apart:

- **A transient failure** — an infrastructure hiccup that says nothing about
  the issue or PR itself: a `gh`/GitHub API rate limit, a request timeout, an
  Atlassian MCP call that errors out. The same call would plausibly succeed a
  moment later.
- **A real blocker** — the call itself succeeded, but what it returned is bad
  news about the issue or PR: a failing AC, CI red, ambiguous scope, a merge
  conflict. Retrying doesn't change any of these — they're facts about the
  work, not about the network.

On a transient failure, retry the same call with exponential backoff: up to
**4 attempts**, waiting **2s, then 4s, then 8s, then 16s** between attempts.
If the 4th retry still fails, stop retrying and treat it as a blocker —
surface it in Summarize (step 8) exactly as any other blocker, rather than
silently dropping the candidate or looping on it indefinitely.

**Real blockers are never retried.** A failing AC, CI red, ambiguous scope,
or a merge conflict surfaces immediately the first time it's seen — this is
unchanged from `/sprint`'s existing behavior. Retry-with-backoff exists only
to absorb infrastructure flakiness in `/sprint`'s own `gh`/MCP calls; it is
never used to paper over, second-guess, or wait out a genuine blocking
condition.

## Notes

- This skill composes the other four skills — it does not re-implement their
  logic. Keep its job to selection, scheduling, and serialization.
- Sub-agents run with their own context; pass them just the issue number and a
  pointer to `CLAUDE.md` + the relevant skill.
