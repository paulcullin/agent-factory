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

2. **Detect overlap before parallelizing.** Read each candidate's `Touches:`
   line (and skim its AC). Group issues that touch the same core
   files/modules — those **must be serialized**, not run together. Issues with
   disjoint footprints can run in parallel.

3. **Implement in parallel (per group).** For each independent issue, spawn an
   `implement` sub-agent:
   - `isolation: "worktree"`
   - `run_in_background: true`

   Each gets its own worktree + branch, loops against `check`, and opens a PR.

4. **Verify on landing.** As each PR opens, spawn a `verify` sub-agent for it.
   It grades AC + confirms CI + optional smoke test, then approves or requests
   changes. On request-changes, hand back to that issue's `implement` agent for
   another loop (respect the 5-iteration cap, then surface a blocker).

5. **Ship — serialized.** Merge approved PRs **one at a time**. After each
   merge, re-run `<runner> check` on `main` before merging the next, so two
   branches that were green in isolation can't land a broken combination.

6. **Summarize.** Report three buckets:
   - **Shipped** — issue # (or Jira key when `issue_tracker: jira`), PR #,
     merge SHA.
   - **Blocked** — issue # (or Jira key), the reason (failing AC, ambiguous
     scope, CI).
   - **Still running** — issue # (or Jira key), current stage.

## Conflict rules (do not violate)

- Never parallelize two issues known to touch the same core files — serialize
  them. Use the `Touches:` hint; when in doubt, serialize.
- Never merge in parallel. Ship is always one-at-a-time with a `check` between.
- Respect each issue's 5-iteration implement cap; escalate as a blocker rather
  than looping forever.

## Notes

- This skill composes the other four skills — it does not re-implement their
  logic. Keep its job to selection, scheduling, and serialization.
- Sub-agents run with their own context; pass them just the issue number and a
  pointer to `CLAUDE.md` + the relevant skill.
