---
name: verify
description: Verify a pull request against its issue's acceptance criteria and post a review. Use when the user says "verify PR N", "review this PR", or "check the work".
---

# /verify — PR → AC-graded review

Grade a PR against its linked issue's acceptance criteria. This is the **eval**
step: be concrete and evidence-based, not vibes. The deterministic `check` gate
proves correctness; this step proves *coverage* of the AC.

## Procedure

1. **Resolve the linked issue** from the PR (the `Closes #<#>` line, or
   `gh pr view <#> --json body,closingIssuesReferences`). Pull its
   `### Acceptance criteria` checklist.

2. **Get the actual changes.** `gh pr diff <#>`.

3. **Grade each AC item individually.** For every checkbox, map it to specific
   evidence:
   - a concrete change at `file:line` in the diff, **or**
   - a test that exercises it (name the test).

   Mark each **PASS** (with evidence) or **GAP** (with what's missing). Do not
   mark pass without pointing at evidence.

4. **Confirm the deterministic gate is green.** `gh pr checks <#>`. CI red ⇒
   request changes regardless of AC coverage.

5. **Optional dynamic check.** If the project has a preview/dev server, start
   it (Preview MCP if available) and smoke-test the golden path. Record what you
   observed.

6. **Post the review.**
   - All AC pass **and** CI green ⇒ `gh pr review <#> --approve` with a summary
     that lists each AC and its evidence.
   - Otherwise ⇒ `gh pr review <#> --request-changes` with **inline comments at
     the gap locations**. Inline line-level comments need the **GitHub MCP**;
     if it's absent, fall back to a single summary review comment via `gh`
     listing each gap and where it should be addressed.

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
