---
name: ship
description: Merge an approved, CI-green PR and clean up its worktree. Use when the user says "ship PR N", "merge it", or "land this".
---

# /ship — merge + cleanup

Land an approved, CI-green PR and clean up after it.

## Procedure

1. **Guard.** Refuse to merge unless **both** hold:
   - CI is green — `gh pr checks <#>`.
   - An **approving** verify review exists — `gh pr reviews <#>` (or
     `gh pr view <#> --json reviews`).

   If either fails, stop and report which guard tripped. Do not override.

2. **Merge.** `gh pr merge <#> --squash --delete-branch`.

3. **Clean up the worktree.** `ExitWorktree` if available, else
   `git worktree remove ../<repo>-<#>` (use `--force` only if it's clean and
   you're sure).

4. **Confirm issue closure.** The `Closes #<#>` in the PR should auto-close the
   linked issue. Verify with `gh issue view <#> --json state`. If it's still
   open, close it with a delivery comment referencing the merge commit SHA.

5. **Append to the log.** Add a line to `docs/00-context.md` (append-only):
   what shipped, the PR/merge SHA, and the closed issue.

## Rules

- **Serialize merges.** When shipping multiple PRs, ship one at a time and
  re-run `<runner> check` on `main` after each merge — two branches that are
  green in isolation can conflict in combination.
- Never force-merge past a red gate or a missing approval.
- Squash-merge keeps `main` history one-commit-per-issue.
