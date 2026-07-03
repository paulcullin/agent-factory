---
name: spec
description: Turn a product or feature idea into a PRD and a set of backlog issues (GitHub or Jira, per the project's issue_tracker setting) with acceptance criteria. Use when the user describes something to build, says "spec this", "write a PRD", "add to the backlog", or "break this down into issues".
---

# /spec — idea → backlog

Turn an idea into a PRD section plus a structured backlog (one Epic + N spec
issues) whose acceptance criteria are precise enough for an implement agent to
satisfy and a verify agent to grade. The backlog lives in GitHub or Jira per
the project's `issue_tracker` setting (see `CLAUDE.md` → "Issue tracker"); the
procedure below is identical in both modes except where a step says
otherwise.

## Procedure

1. **Interview-lite.** If the idea is thin, ask **≤3** clarifying questions —
   prioritize: target users, the success metric, hard constraints. If the idea
   is already concrete, skip the questions and proceed. This step does not
   change with `issue_tracker`.

2. **Draft the PRD section** (show it to the user; also fold the durable parts
   into `docs/` if the project keeps a product doc):
   - **Problem** — what's broken / missing and for whom.
   - **Goals / Non-goals** — explicit scope boundaries.
   - **User stories** — "As a … I want … so that …".
   - **Constraints** — technical, platform, performance, deadline.

3. **Decompose into one Epic + N spec issues** (in `jira` mode: one Epic + N
   Stories — same content, Jira's naming). Each spec issue/Story must:
   - Have a **title that is an imperative outcome** ("Capture photo while
     offline", not "Offline stuff").
   - Begin its body/description with a back-link to the epic:
     - `github` mode: `Epic: #<n>`.
     - `jira` mode: `Epic: <JIRA-KEY>` (e.g. `Epic: PROJ-100`) — the Jira key
       of the Epic created in step 4, not a GitHub-style `#<n>`.
   - Contain an `### Acceptance criteria` section of `- [ ]` checkboxes that are
     **individually verifiable** — each maps to one code change or one test.
     This section and its quality bar (below) are identical in both modes.
   - Be **sized for one PR by one agent** (slice along file/module boundaries
     so parallel agents don't collide — see the conflict note below).
   - Optionally include a `Touches:` line listing the modules/files it will
     change, so `/sprint` can detect overlap and serialize. Include this line
     in both modes — `/sprint`'s overlap detection reads it regardless of
     tracker.

4. **Create the issues.** Fork on `issue_tracker`:
   - `github` (default): use `gh issue create`, labels `epic` / `spec`. Use
     `--body-file -` with a heredoc (proven reliable). Create the epic first
     so you have its number for the back-links.
   - `jira`: use the Atlassian MCP (discovered via `ToolSearch` — do not
     hardcode specific tool names, they're environment-dependent) instead of
     any CLI; per `CLAUDE.md`'s Jira exception this path has no CLI fallback.
     Create the Epic first, in the project identified by `jira_project_key`,
     to obtain its Jira key. Then, for each spec issue, create a Story in the
     same project and link it to that Epic (via the MCP's epic-link
     mechanism), with its description built per step 3 (`Epic: <JIRA-KEY>`
     back-link, `Touches:` line, `### Acceptance criteria` section).

5. **Return the created identifiers** so the user or `/sprint` can hand off:
   `github` mode returns issue numbers (e.g. `#42`); `jira` mode returns the
   created issue keys (e.g. `PROJ-101`) in their place.

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

This example is for `github` mode. In `jira` mode the same content (title,
`Epic: <JIRA-KEY>` back-link, `Touches:` line, `### Acceptance criteria`
section) goes into the Atlassian MCP's create-issue call instead of a `gh`
heredoc — the MCP has no CLI equivalent to shell out to.

## Conflict note (slice to avoid collisions)

Try to slice issues so that no two specs touch the same core files. When two
specs genuinely must touch shared code, say so in their `Touches:` lines —
`/sprint` will serialize them instead of running them in parallel.
