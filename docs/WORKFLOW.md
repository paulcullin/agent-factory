# WORKFLOW — the agentic pipeline, end to end

This is the human-facing guide to how a project built from **agent-factory**
goes from idea to merged code. The machinery is five Claude Code skills plus a
single verification gate.

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

## Known gotchas

- **Workflow token scope.** Pushing a `.github/workflows/*.yml` file needs the
  `workflow` scope on your GitHub token. If a push is rejected, run
  `gh auth refresh -s workflow`.
- **Merge ordering.** Two PRs green in isolation can conflict in combination.
  `/ship` (and `/sprint`'s ship phase) merges one at a time and re-runs `check`
  on `main` between merges.

Reference implementation that proved the pattern: `paulcullin/fieldlens`.
