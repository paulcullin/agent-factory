---
name: verify
description: Verify a pull request against its issue's acceptance criteria and post a review. Use when the user says "verify PR N", "review this PR", or "check the work".
---

# /verify — PR → AC-graded review

Grade a PR against its linked issue's acceptance criteria. This is the **eval**
step: be concrete and evidence-based, not vibes. The deterministic `check` gate
proves correctness; this step proves *coverage* of the AC.

## Procedure

1. **Resolve the linked issue.** Forks on the project's `issue_tracker`
   config (see `CLAUDE.md`):
   - `github` mode (default, unchanged): from the PR (the `Closes #<#>` line,
     or `gh pr view <#> --json body,closingIssuesReferences`). Pull its
     `### Acceptance criteria` checklist.
   - `jira` mode: read the PR body (`gh pr view <#> --json body`) for its
     `Jira: <JIRA-KEY>` line to get the Jira key, then pull that issue's
     acceptance criteria via the Atlassian MCP (discovered via `ToolSearch`)
     instead of `gh pr view --json closingIssuesReferences`. Per `CLAUDE.md`,
     the Atlassian MCP is a hard dependency for this path — no CLI fallback.

2. **Get the actual changes.** `gh pr diff <#>`. Inline code-location
   comments always target the GitHub PR — that's where the diff lives —
   regardless of `issue_tracker`.

3. **Grade each AC item individually.** For every checkbox, map it to specific
   evidence:
   - a concrete change at `file:line` in the diff, **or**
   - a test that exercises it (name the test).

   Mark each **PASS** (with evidence) or **GAP** (with what's missing). Do not
   mark pass without pointing at evidence. This grading procedure is
   unchanged in `jira` mode — only the source of the AC list (step 1)
   differs.

4. **Confirm the deterministic gate is green.** `gh pr checks <#>`. CI red ⇒
   request changes regardless of AC coverage.

5. **Optional dynamic check.** If the project has a preview/dev server, start
   it (Preview MCP if available) and smoke-test the golden path. Record what you
   observed.

6. **Post the review.**
   - **Check identity first.** Compare the PR author (`gh pr view <#> --json
     author`) to the authenticated `gh` user (`gh api user`). If they're the
     **same identity**, `gh pr review --approve` will always fail — GitHub
     blocks self-approval by identity, not by review content. Skip the
     attempt entirely: post the verdict as a plain `gh pr comment` using the
     same body (see Output format), and say explicitly that a human must
     manually approve before `/ship`'s guard will pass. Do not spend a turn
     discovering this failure — check identity up front.
   - Otherwise, when a **different** identity is verifying: all AC pass **and**
     CI green ⇒ `gh pr review <#> --approve` with a summary that lists each AC
     and its evidence.
   - Otherwise (AC gaps or CI red) ⇒ `gh pr review <#> --request-changes` with
     **inline comments at the gap locations**. Inline line-level comments need
     the **GitHub MCP**; if it's absent, fall back to a single summary review
     comment via `gh` listing each gap and where it should be addressed.
   - **`jira` mode, in addition to the GitHub PR review above:** post the same
     `## AC grade` / `## Verdict` summary (see Output format) as a comment on
     the Jira issue via the Atlassian MCP. On request-changes, also transition
     the Jira issue back to an "in progress"-style status via the Atlassian
     MCP, if a suitable transition is available — don't leave it in whatever
     status `/implement` left it. This is additive to the GitHub-side review;
     it does not replace it.

## Output format (the review body)

```
## AC grade
- [x] <criterion 1> — PASS: src/capture.ts:42; test `captures while offline`
- [ ] <criterion 2> — GAP: no test covers the processing-state transition

## Deterministic gate
CI: <green/red> (gh pr checks)

## Smoke test (if run)
<what you observed on the golden path>

## Verdict
<approve | request-changes> — <one-line reason>
```

## Rules

- Every PASS cites evidence (file:line or a named test). No evidence ⇒ GAP.
- Never approve with CI red.
- Never approve if any AC is a GAP — request changes and say exactly what's
  missing and where.
