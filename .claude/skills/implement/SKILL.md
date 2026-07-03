---
name: implement
description: Implement a GitHub issue end-to-end in an isolated git worktree and open a PR. Use when the user says "implement #N", "build issue N", or "pick up the next backlog item".
---

# /implement — issue → PR

Implement exactly one issue's acceptance criteria in an isolated worktree and
open a PR that the `/verify` step can grade.

## Procedure

Code always stays on GitHub — both modes work in a git worktree in this repo
and open a `gh pr create` PR here. Only where the AC comes from, how the
branch/PR are named, and how progress is reported back to the tracker differ.
Check `issue_tracker` in `CLAUDE.md` before step 1.

1. **Read the contract.**
   - `github` mode (default): `gh issue view <#> --json title,body`. The
     `### Acceptance criteria` checklist is the spec.
   - `jira` mode: read the AC from the Jira issue identified by its key (e.g.
     `PROJ-101`) via the Atlassian MCP (discovered via `ToolSearch`) instead of
     `gh issue view`. The issue's AC field/description is the spec.

   In both modes: if no AC exists, or the AC is ambiguous, **comment on the
   issue and stop** — do not guess scope. In `jira` mode, "comment on the
   issue" means posting a comment on the Jira issue via the Atlassian MCP.

2. **Isolate.** Create a worktree + branch so parallel agents never collide:
   - Preferred: use the `EnterWorktree` tool if available (it manages
     lifecycle and cleanup).
   - Fallback: `git worktree add ../<repo>-<#> -b feature/issue-<#>`.
   - `jira` mode: name the branch with the Jira key in place of the GitHub
     issue number, e.g. `feature/proj-101` (lowercase the key for the branch
     name).

   Work **inside that worktree only**.

3. **Implement exactly the AC** — nothing more. Each checkbox maps to a code
   change or a test. Keep new logic in the pure core with colocated tests;
   push side effects to the edges.

4. **Loop against the gate:** implement → `<runner> check` → fix → repeat.
   **Cap at ~5 iterations.** If still red after that, stop and surface the
   blocker rather than thrashing — comment on the issue with the failing
   output (in `jira` mode, comment on the Jira issue via the Atlassian MCP).
   This cap and the ambiguous-AC rule apply identically in both modes.

5. **Commit & open the PR.** The PR always lives on GitHub, in both modes.
   - Commit message references the issue: the GitHub issue number in `github`
     mode (e.g. `feat: capture offline (#<#>)`), or the Jira key in `jira`
     mode (e.g. `feat: capture offline (PROJ-101)`).
   - `github` mode: `gh pr create` with the PR template body; it must include
     `Closes #<#>` and restate the AC as a `- [ ]` checklist for verify to
     grade.
   - `jira` mode: `gh pr create` with a PR body that includes a
     `Jira: <JIRA-KEY>` line (e.g. `Jira: PROJ-101`) instead of `Closes #<#>`
     — Jira keys don't trigger GitHub's auto-close syntax — while still
     restating the AC as a `- [ ]` checklist for verify to grade. `/verify`
     and `/ship` resolve the Jira key from this exact `Jira: <JIRA-KEY>` line.
   - `jira` mode only, after the PR is open: post a comment on the Jira issue
     with the PR URL via the Atlassian MCP, and transition the issue to an
     "in progress"-style status via the Atlassian MCP if such a transition is
     available. Skip the transition silently if none applies — don't block
     on it.

6. **Append to the running log.** Add a short entry to `docs/00-context.md`
   (append-only) noting what was built and any decisions; record non-trivial
   choices as an ADR under `docs/adr/`.

7. **Return the PR number.**

## Invariants (do not violate)

These are tracker-agnostic and unchanged between `github` and `jira` modes.

- **Never force-push.**
- **Never touch files outside the issue's scope.**
- **Never merge** here — that's `/ship`'s job, and only after verify approves.
- If the AC is ambiguous, comment on the issue and stop (in `jira` mode, that
  means the Jira issue, via the Atlassian MCP). Do not guess.
- Stay inside the worktree; never commit to `main` directly.

## Notes

- `<runner>` is the project's gate command (e.g. `npm run check`). It is the
  sole arbiter of correctness; do not declare done until it is green.
- If the change needs a new dependency, install it within the worktree and let
  `check` validate the build.
- In `jira` mode, the Atlassian MCP is a **hard dependency with no CLI
  fallback** (see the Conventions exception in `CLAUDE.md`) — if it isn't
  available, stop and surface the blocker rather than guessing at a
  workaround. Never hardcode specific Atlassian MCP tool function names here;
  discover them via `ToolSearch` at runtime.
