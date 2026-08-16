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
   - **Resume path.** Before scaffolding anything, check whether a
     worktree/branch for this issue already exists (`feature/issue-<#>`, or
     the Jira-key equivalent in `jira` mode) — typically because a prior run
     was interrupted (crash, timeout, `/sprint` circuit breaker) before the
     issue shipped. If it does, **reuse it**: re-enter the existing worktree
     (or `git worktree add` against the existing branch if the worktree
     directory itself was cleaned up but the branch survived) and continue
     from its current committed state. Do not delete, re-create, or
     force-reset the branch, and do not redo work already committed — pick
     back up at step 3 with whatever the branch already has, and carry the
     iteration count forward per step 4's resume tracking below. Only fall
     back to fresh scaffolding when no such worktree/branch exists.

   Work **inside that worktree only**. If `CLAUDE.md`'s **Monorepo scope** has
   `monorepo: true`, note that a worktree still checks out the *whole* repo
   (git worktrees aren't package-scoped) — treat
   `<worktree>/<package_path>` as the working root for `<runner> check` and
   every edit. Never touch files outside `package_path`.

3. **Implement exactly the AC** — nothing more. Each checkbox maps to a code
   change or a test. Keep new logic in the pure core with colocated tests;
   push side effects to the edges.

4. **Loop against the gate:** implement → `<runner> check` → fix → repeat.
   **Cap at ~5 iterations.** If still red after that, stop and surface the
   blocker rather than thrashing — comment on the issue with the failing
   output (in `jira` mode, comment on the Jira issue via the Atlassian MCP).
   This cap and the ambiguous-AC rule apply identically in both modes.

   **Tracking the cap across a resume.** The cap is scoped to the issue's
   branch, not to any single process's lifetime — resuming a worktree (step
   2's resume path) must not reset the count back to 5 fresh iterations, or a
   repeatedly-interrupted issue could loop indefinitely across resumes. On
   resume, recover how many iterations are already spent by counting the
   commits already made on the branch since it diverged from `main` — e.g.
   `git log main..HEAD --oneline | wc -l` — and treat that count as
   iterations already consumed against the cap. Continue the loop from that
   count rather than from zero: e.g. a branch with 3 commits already on it
   gets at most 2 more `check`-and-fix iterations before it must stop and
   surface a blocker.

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
