---
name: spec
description: Turn a product or feature idea into a PRD and a set of GitHub issues with acceptance criteria. Use when the user describes something to build, says "spec this", "write a PRD", "add to the backlog", or "break this down into issues".
---

# /spec — idea → backlog

Turn an idea into a PRD section plus a structured GitHub backlog (one Epic + N
spec issues) whose acceptance criteria are precise enough for an implement
agent to satisfy and a verify agent to grade.

## Procedure

1. **Interview-lite.** If the idea is thin, ask **≤3** clarifying questions —
   prioritize: target users, the success metric, hard constraints. If the idea
   is already concrete, skip the questions and proceed.

2. **Draft the PRD section** (show it to the user; also fold the durable parts
   into `docs/` if the project keeps a product doc):
   - **Problem** — what's broken / missing and for whom.
   - **Goals / Non-goals** — explicit scope boundaries.
   - **User stories** — "As a … I want … so that …".
   - **Constraints** — technical, platform, performance, deadline.

3. **Decompose into one Epic + N spec issues.** Each spec issue must:
   - Have a **title that is an imperative outcome** ("Capture photo while
     offline", not "Offline stuff").
   - Begin its body with `Epic: #<n>` (back-link to the epic).
   - Contain an `### Acceptance criteria` section of `- [ ]` checkboxes that are
     **individually verifiable** — each maps to one code change or one test.
   - Be **sized for one PR by one agent** (slice along file/module boundaries
     so parallel agents don't collide — see the conflict note below).
   - Optionally include a `Touches:` line listing the modules/files it will
     change, so `/sprint` can detect overlap and serialize.

4. **Create the issues** with `gh issue create`, labels `epic` / `spec`. Use
   `--body-file -` with a heredoc (proven reliable). Create the epic first so
   you have its number for the back-links.

5. **Return the created issue numbers** so the user or `/sprint` can hand off.

## Acceptance-criteria quality bar (check every criterion)

- **Testable** — you can point at a test or an observable behavior.
- **Scoped** — one assertion, no "and also" compounds.
- **Concrete** — names the precondition, action, and observable result.

Bad: "works well offline."
Good: "With `navigator.onLine === false`, capture succeeds and the photo
appears in the gallery in `processing` state."

If you cannot write a criterion that meets this bar, the issue is too vague to
implement — split it or ask another clarifying question. **No AC = no work.**

## Example issue body (heredoc → `gh`)

```bash
EPIC=$(gh issue create --label epic --title "Offline capture" \
  --body "Goal: capture works with no network." --json number -q .number 2>/dev/null \
  || gh issue create --label epic --title "Offline capture" --body "Goal: capture works with no network.")

gh issue create --label spec --title "Capture photo while offline" --body-file - <<EOF
Epic: #${EPIC}

Touches: src/capture, src/gallery

### Acceptance criteria
- [ ] With \`navigator.onLine === false\`, \`capturePhoto()\` resolves successfully.
- [ ] A captured-while-offline photo appears in the gallery in \`processing\` state.
- [ ] A unit test covers the offline path of \`capturePhoto()\`.
EOF
```

## Conflict note (slice to avoid collisions)

Try to slice issues so that no two specs touch the same core files. When two
specs genuinely must touch shared code, say so in their `Touches:` lines —
`/sprint` will serialize them instead of running them in parallel.
