# WORKFLOW — the agentic pipeline, end to end

This is the human-facing guide to how a project built from **agent-factory**
goes from idea to merged code. The machinery is five Claude Code skills plus a
single verification gate. A sixth skill, **`/onboard`**, is a one-time
bootstrap step for adopting into an existing project (see
`docs/ADOPTING.md`) — it's not part of the idea→ship pipeline below.

## The pipeline at a glance

```
  idea ──/spec──▶ Epic + spec issues (AC checkboxes, labels)
                        │
                  /sprint picks top N
                        │
        ┌───────────────┼───────────────┐         (parallel, isolated)
   /implement #a    /implement #b    /implement #c
   worktree+branch  worktree+branch  worktree+branch
   loop vs `check`  loop vs `check`  loop vs `check`
        │ PR             │ PR             │ PR
   /verify (AC grade + CI + smoke) each
        │ approve        │ approve        │ approve
        └──── /ship (serialized): merge + worktree cleanup ────┘
                        │
                  issues auto-close, docs/00-context.md appended
```

## The five steps

| Step | Command | Input → Output | What it guarantees |
|---|---|---|---|
| Spec | `/spec <idea>` | idea → Epic + spec issues | Every issue has verifiable `- [ ]` AC |
| Implement | `/implement <#>` | issue → PR | Built in an isolated worktree, exactly the AC, `check` green |
| Verify | `/verify <#>` | PR → review | Each AC mapped to evidence; CI confirmed; optional smoke test |
| Ship | `/ship <#>` | approved PR → `main` | Merged only with CI green + verify approval; worktree cleaned |
| Sprint | `/sprint [N]` | backlog → shipped | Orchestrates N issues, parallel where safe, serial where they collide |

## The design principles (why it's reliable)

1. **One verification gate.** A single `<runner> check` (typecheck + lint +
   test + build) is the sole arbiter of "is this safe." Agents loop against it.
2. **Acceptance criteria are the spec.** Issue bodies carry `- [ ]` checkboxes;
   implement satisfies exactly those, verify grades against them. **No AC = no
   work.**
3. **Isolation per unit of work.** One git worktree + branch per issue, so
   parallel agents never collide.
4. **Docs accumulate.** A running context log (`docs/00-context.md`, append-only)
   + ADRs (`docs/adr/`) are part of every change.
5. **Deterministic before AI.** `check` gates correctness; AI verify gates
   *coverage* of the AC. AI judgment never replaces the deterministic gate.

## Day-to-day usage

1. **Start a project:** "Use this template" on GitHub, or run
   `scripts/new-project.sh <name> --stack node-ts`.
2. **Set up labels** (if not done by the script): `scripts/setup-labels.sh`.
3. **Spec the work:** `/spec <your idea>` → review the PRD + issues it files.
4. **Run a sprint:** `/sprint 3` → it implements, verifies, and ships the top 3.
   Or drive a single issue manually: `/implement 12` → `/verify <pr>` →
   `/ship <pr>`.
5. **Watch the gate:** CI runs `check` on every push/PR; nothing merges red.

## Recommended tools / MCPs

**Rule of thumb: prefer the GitHub MCP, fall back to `gh`.** Use the MCP for
richer/structured GitHub operations when it's wired up; otherwise everything
still works through the `gh` CLI, which is the required baseline. `gh` is also
the only option in the `scripts/` helpers and CI (no MCP there), so the skills
keep their `gh` form as the portable default and never hard-depend on an MCP
server. See `CLAUDE.md` → Conventions.

| Tool | Why it matters | Priority |
|---|---|---|
| **GitHub MCP** (official) | Line-level PR review comments for `/verify`; richer structured GitHub ops; preferred when available | High |
| `gh` CLI | Issue/PR/label CRUD; the required baseline everything falls back to, and the only option in scripts + CI | Required |
| **Atlassian MCP** | Epic/Story CRUD, AC retrieval, comments, and status transitions in Jira; **required, no CLI fallback**, when `issue_tracker: jira` | Required (Jira mode only) |
| Preview MCP | Dynamic smoke tests in `/verify` | Medium |
| Playwright / WebKit | Device-realistic E2E once a project has a UI | Per-project |
| `fewer-permission-prompts` skill | Tighten the AFK allowlist from real runs | Low |

## Autonomous operation

`/sprint` is built to run unattended, not only on manual invocation. Wire it
to a recurring scheduled trigger — a cron-based Routine, or whatever equivalent
scheduling mechanism your environment provides — that fires `/sprint [N]` on
an interval (e.g. every few hours) against the open backlog. Each firing picks
up wherever the backlog and any in-progress work currently stand; nothing in
the skill assumes a human kicked it off.

Doing this safely depends on the safety envelope added across epic #19, all
already built into `.claude/skills/sprint/SKILL.md` (and, for resumability,
`.claude/skills/implement/SKILL.md`):

- **Circuit breaker (step 2).** Two run-scoped counters — consecutive
  blocked/failed issues (trips the breaker once it hits 3 in a row, reset to
  zero on each Shipped outcome) and total issues attempted this run (trips at
  a per-run cap of 10, independent of `N`) — stop `/sprint` from selecting or
  spawning any *new* work once either trips. Issues already in flight still
  run to completion; the breaker just keeps a systemic problem from burning
  through the whole backlog unattended.
- **Resumability (step 5's resume-check).** Before spawning a fresh
  `implement` sub-agent, `/sprint` checks whether a worktree/branch already
  exists for that issue (`feature/issue-<#>`, or the lowercased Jira-key
  branch in `jira` mode) and resumes it instead of starting over. This is the
  case that matters most for a scheduled trigger: a container recycle or a
  trigger firing mid-run shouldn't throw away work already done on an issue.
  `/implement`'s own "Isolate" step (and its `check`-loop iteration count)
  documents the resume path in full.
- **Kill switch (step 3).** Dropping a `.claude/STOP` file at the repo root
  halts selection and new spawns at the very next between-issues checkpoint —
  see "Halting an unattended `/sprint` run" below for both ways to stop a run.
- **Transient-failure backoff ("Transient failures vs. blockers").**
  `/sprint`'s own direct `gh`/MCP calls (Select work, Detect overlap, Ship)
  retry infrastructure hiccups — rate limits, timeouts — up to 4 attempts with
  2s/4s/8s/16s backoff before surfacing them as blockers, so a flaky network
  moment doesn't sink an otherwise-healthy unattended run. Real blockers
  (failing AC, CI red, ambiguous scope, a merge conflict) are never retried —
  they surface immediately, exactly as in manual use.

Together, these mean an unattended run degrades gracefully under trouble — it
stops starting new work rather than thrashing indefinitely — and either a
human or the next scheduled firing can resume cleanly from where it left off.

**Known constraint: `/ship` still needs a human at the merge.** Even with all
four safeguards above in place, a scheduled `/sprint` run is not fully
autonomous end to end. Per `CLAUDE.md` → Gotchas ("PR self-approval is
blocked"): when `/verify` runs under the same identity that authored the PR
(the default single-account setup), GitHub refuses `gh pr review --approve`
outright, so `/verify` posts its AC grade as a PR comment instead of an
approval — a human still has to approve the PR by hand before `/ship`'s guard
(which requires an approving review) will let it merge. So a scheduled
`/sprint` run will implement and verify unattended, but shipped PRs still
queue on that one human checkpoint; account for it in your trigger cadence and
in how promptly someone checks in on approvals.

## Halting an unattended `/sprint` run

`/sprint` is meant to be runnable unattended — e.g. on a recurring scheduled
trigger — but any autonomous loop needs a clean way to stop it. There are two
ways, in order of reversibility:

1. **Disable the scheduling trigger.** If `/sprint` is firing on a recurring
   schedule, disabling (or deleting) that trigger stops future invocations
   from starting at all. This is the right choice for a planned pause: no
   in-progress run is interrupted, nothing needs cleaning up, and you just
   re-enable the trigger when ready to resume.
2. **Drop the `.claude/STOP` marker file.** For an immediate halt on a run
   that's already in progress, create an empty `.claude/STOP` file at the
   repo root (e.g. `touch .claude/STOP`). `/sprint`'s kill-switch step
   (`.claude/skills/sprint/SKILL.md`, step 3) checks for this file **only
   between issues** — before selecting new work and before spawning each new
   `implement` sub-agent — and never mid-issue. Any issue already in
   implement/verify/ship keeps running to completion; only the *not-yet-started*
   selected issues are left untouched, and the run's summary reports them in
   a **Halted** bucket. Remove the file once you're ready to let future runs
   select new work again.

Use (1) for a durable pause between runs, and (2) when you need the very
next between-issues checkpoint of a run already underway to stop immediately.

## Known gotchas

- **Workflow token scope.** Pushing a `.github/workflows/*.yml` file needs the
  `workflow` scope on your GitHub token. If a push is rejected, run
  `gh auth refresh -s workflow`.
- **Merge ordering.** Two PRs green in isolation can conflict in combination.
  `/ship` (and `/sprint`'s ship phase) merges one at a time and re-runs `check`
  on `main` between merges.

Reference implementation that proved the pattern: `paulcullin/fieldlens`.
