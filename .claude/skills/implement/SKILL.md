---
name: implement
description: Implement a GitHub issue end-to-end in an isolated git worktree and open a PR. Use when the user says "implement #N", "build issue N", or "pick up the next backlog item".
---

# /implement — issue → PR

Implement exactly one issue's acceptance criteria in an isolated worktree and
open a PR that the `/verify` step can grade.

## Procedure

1. **Read the contract.** `gh issue view <#> --json title,body`. The
   `### Acceptance criteria` checklist is the spec. If no AC exists, or the AC
   is ambiguous, **comment on the issue and stop** — do not guess scope.

2. **Isolate.** Create a worktree + branch so parallel agents never collide:
   - Preferred: use the `EnterWorktree` tool if available (it manages
     lifecycle and cleanup).
   - Fallback: `git worktree add ../<repo>-<#> -b feature/issue-<#>`.

   Work **inside that worktree only**.

3. **Implement exactly the AC** — nothing more. Each checkbox maps to a code
   change or a test. Keep new logic in the pure core with colocated tests;
   push side effects to the edges.

4. **Loop against the gate:** implement → `<runner> check` → fix → repeat.
   **Cap at ~5 iterations.** If still red after that, stop and surface the
   blocker (comment on the issue with the failing output) rather than thrashing.

5. **Commit & open the PR.**
   - Commit message references the issue (e.g. `feat: capture offline (#<#>)`).
   - `gh pr create` with the PR template body: it must include `Closes #<#>`
     and restate the AC as a `- [ ]` checklist for verify to grade.

6. **Append to the running log.** Add a short entry to `docs/00-context.md`
   (append-only) noting what was built and any decisions; record non-trivial
   choices as an ADR under `docs/adr/`.

7. **Return the PR number.**

## Invariants (do not violate)

- **Never force-push.**
- **Never touch files outside the issue's scope.**
- **Never merge** here — that's `/ship`'s job, and only after verify approves.
- If the AC is ambiguous, comment on the issue and stop. Do not guess.
- Stay inside the worktree; never commit to `main` directly.

## Notes

- `<runner>` is the project's gate command (e.g. `npm run check`). It is the
  sole arbiter of correctness; do not declare done until it is green.
- If the change needs a new dependency, install it within the worktree and let
  `check` validate the build.
