# Agent Factory — Bootstrap Blueprint

> **Purpose of this file.** This is a self-contained build spec for a
> *template repository* ("agent-factory") that stamps out new software
> projects pre-wired for AFK agentic development. It was written with warm
> context from the FieldLens project (the reference implementation of this
> workflow). A fresh Claude Code session should be able to read this file and
> build the whole thing. **Read it top to bottom before writing code.**

---

## 0. What we are building & why

We want a workflow that takes a product/feature idea and carries it
autonomously through: **idea → PRD/spec → GitHub backlog (tagged, formatted)
→ parallel implementation in isolated worktrees → eval/verify against
acceptance criteria → merge & cleanup.**

The deliverable is a **GitHub template repo** (`agent-factory`) you click
"Use this template" on (or run a `create` script against) to start any new
project with this machinery already installed. The machinery is a set of
**Claude Code skills** + **conventions** + **CI**, not application code — it's
language-agnostic scaffolding, with one worked example.

The reference implementation that proved the pattern is **FieldLens**
(`paulcullin/fieldlens`): docs-driven decision trail, pure testable core,
single `npm run check` gate, issue-per-spec backlog with checkbox acceptance
criteria. This blueprint generalizes those patterns.

### Design principles (carried from FieldLens, do not violate)

1. **One verification gate.** Every project exposes a single command
   (`<runner> check`) that runs typecheck + lint + test + build and is the
   sole arbiter of "is this safe." Agents loop against it.
2. **Acceptance criteria are the spec.** Issue bodies carry `- [ ]`
   checkboxes; implement agents satisfy exactly those; verify agents grade
   against them. No AC = no work.
3. **Isolation per unit of work.** One git worktree + branch per issue, so
   parallel agents never collide.
4. **Docs accumulate.** A running context log + ADRs are part of every
   change, never an afterthought.
5. **Deterministic before AI.** `check` (deterministic) gates correctness;
   AI verify gates *coverage* of the AC. Never let AI judgment replace the
   deterministic gate.

---

## 1. Repository layout to build

```
agent-factory/
├── README.md                      # what this template is, how to use it
├── CLAUDE.md                      # the agentic working agreement (the heart)
├── .claude/
│   ├── settings.json              # permission allowlist for AFK runs
│   └── skills/
│       ├── spec/SKILL.md          # idea  → backlog
│       ├── implement/SKILL.md     # issue → PR (worktree)
│       ├── verify/SKILL.md        # PR    → AC-graded review
│       ├── ship/SKILL.md          # PR    → merge + cleanup
│       └── sprint/SKILL.md        # orchestrator: backlog → parallel agents
├── .github/
│   ├── workflows/ci.yml           # runs `check` on push/PR
│   ├── ISSUE_TEMPLATE/
│   │   ├── epic.md
│   │   └── spec.md                # forces the AC checklist format
│   └── PULL_REQUEST_TEMPLATE.md   # links issue, restates AC
├── docs/
│   ├── 00-context.md              # running context log (seed it)
│   ├── adr/
│   │   ├── ADR-0000-template.md
│   │   └── ADR-0001-agentic-workflow.md   # records THIS workflow choice
│   └── WORKFLOW.md                # human-facing guide to the pipeline
├── scripts/
│   ├── new-project.sh             # stamp a fresh project from this template
│   └── setup-labels.sh            # create epic/spec/backlog labels in a repo
└── templates/                     # per-stack starters the `create` step picks
    ├── node-ts/                   # mirrors FieldLens tooling
    │   ├── package.json           # has the `check` script
    │   └── ...
    └── README.md                  # how to add a new stack template
```

> If building the full multi-stack `templates/` is too much for one session,
> ship `node-ts` only (it's the proven one) and leave a backlog issue for
> others. Do NOT skip the skills or CLAUDE.md — those are the actual product.

---

## 2. The skills (this is the real deliverable)

Each skill is a directory under `.claude/skills/<name>/` with a `SKILL.md`
containing YAML frontmatter (`name`, `description`) and a procedure. Write
descriptions so they trigger on natural phrasing. Keep each skill focused;
they compose.

### 2.1 `/spec <idea>` — idea → backlog

**Frontmatter description** (for triggering): "Turn a product or feature idea
into a PRD and a set of GitHub issues with acceptance criteria. Use when the
user describes something to build, says 'spec this', 'write a PRD', 'add to
the backlog', or 'break this down into issues'."

**Procedure the skill should encode:**
1. Interview-lite: if the idea is thin, ask ≤3 clarifying questions
   (users, success metric, hard constraints). Otherwise proceed.
2. Draft a PRD section: problem, goals/non-goals, user stories, constraints.
3. Decompose into one **Epic** + N **spec** issues. Each spec:
   - Title is an imperative outcome.
   - Body starts with `Epic: #<n>` (back-link).
   - Body contains an **Acceptance criteria** section of `- [ ]` items that
     are *individually verifiable* (map to a code change or a test).
   - Sized to be implementable in one PR by one agent.
4. Create via `gh issue create`, labels `epic` / `spec`. Use
   `--body-file -` with a heredoc (proven reliable in FieldLens).
5. Return the created issue numbers so the user/orchestrator can hand off.

**Quality bar for AC** (put this in the skill as a checklist): each criterion
is testable, scoped, and free of "and also" compound requirements. Bad:
"works well offline." Good: "with `navigator.onLine === false`, capture
succeeds and the photo appears in the gallery in `processing` state."

### 2.2 `/implement <issue#>` — issue → PR

**Description:** "Implement a GitHub issue end-to-end in an isolated git
worktree and open a PR. Use when the user says 'implement #N', 'build issue
N', or 'pick up the next backlog item'."

**Procedure:**
1. `gh issue view <#> --json title,body` — the AC is the contract.
2. Create worktree + branch:
   `git worktree add ../<repo>-<#> -b feature/issue-<#>` (or use the
   `EnterWorktree` tool if available — preferred, it manages lifecycle).
3. Work *inside that worktree only*. Implement exactly the AC, nothing more.
4. Loop: implement → `<runner> check` → fix → repeat. Cap at ~5 iterations
   before surfacing a blocker rather than thrashing.
5. Commit with a message referencing the issue; open PR with
   `gh pr create`, body = PR template (links `Closes #<#>`, restates AC as a
   checklist the verify step will grade).
6. Return the PR number.

**Invariants to bake in:** never force-push; never touch files outside the
issue's scope; if AC is ambiguous, comment on the issue and stop rather than
guess.

### 2.3 `/verify <pr#>` — PR → AC-graded review

**Description:** "Verify a pull request against its issue's acceptance
criteria and post a review. Use when the user says 'verify PR N', 'review
this PR', or 'check the work'."

**Procedure:**
1. Resolve the linked issue from the PR; pull its AC checklist.
2. `gh pr diff <#>` — get the actual changes.
3. For **each** AC item, map it to specific evidence in the diff
   (file:line) or to a test that covers it. Mark pass/gap explicitly. This is
   the eval — be concrete, not vibes.
4. Confirm the deterministic gate is green (CI status via `gh pr checks`).
5. Optional dynamic check: if the project has a preview/dev server, start it
   and smoke-test the golden path (Preview MCP).
6. Post results: `gh pr review --approve` if all AC pass + CI green;
   otherwise `--request-changes` with **inline comments** at the gap
   locations (this needs the GitHub MCP for line-level comments; fall back to
   a summary review comment via `gh` if MCP absent).

### 2.4 `/ship <pr#>` — merge + cleanup

**Description:** "Merge an approved, CI-green PR and clean up its worktree.
Use when the user says 'ship PR N', 'merge it', or 'land this'."

**Procedure:**
1. Guard: refuse unless CI green AND an approving verify review exists.
2. `gh pr merge <#> --squash --delete-branch`.
3. `git worktree remove ../<repo>-<#>` (or `ExitWorktree`).
4. Confirm the linked issue auto-closed (the `Closes #` did it); if not,
   close with a delivery comment referencing the merge commit.

### 2.5 `/sprint [N]` — orchestrator

**Description:** "Run the agentic backlog: pick the top N open spec issues
and drive them through implement → verify → ship in parallel. Use for 'run
the sprint', 'work the backlog', or 'build the next N issues'."

**Procedure:**
1. `gh issue list --label spec --state open` ordered by milestone/priority.
2. Take up to N (default 3; practical ceiling ~5 — memory + merge-conflict
   risk on shared files).
3. For each: spawn an **`implement` sub-agent** with
   `isolation: "worktree"`, `run_in_background: true`.
4. As each PR lands, spawn a **`verify` sub-agent**; on approval, run
   `ship`.
5. Serialize the merge step (ship one at a time, re-running `check` after
   each merge) to avoid integrating two green-in-isolation branches that
   conflict in combination.
6. Summarize: shipped, blocked (with reasons), still running.

> **Conflict note for the build:** the orchestrator must NOT parallelize
> issues known to touch the same core files. The `spec` skill should try to
> slice issues along file/module boundaries; the `sprint` skill should detect
> overlap (e.g. by a `touches:` hint in issue metadata) and serialize those.

---

## 3. CLAUDE.md template (the working agreement)

The generated `CLAUDE.md` is what makes AFK runs reliable. It must contain:

```markdown
## Commands
- `<runner> check` — the verification gate (typecheck + lint + test + build).
  Run before declaring any change done.

## Agentic mode
- The acceptance criteria in a worked issue ARE the spec. Implement exactly
  those — no more, no less. Each criterion maps to a code change or a test.
- Loop: implement → check → fix → check. Max 5 iterations, then surface a
  blocker (comment on the issue) instead of thrashing.
- One worktree + branch per issue. Never work across issues in one branch.
- Never force-push. Never merge without `check` green AND a verify approval.
- If AC is ambiguous, comment on the issue and stop. Do not guess scope.

## Conventions
- Tests colocated with modules; new core logic requires tests.
- Docs are part of the change: decisions → docs/adr/, running notes →
  docs/00-context.md (append-only).
- Scope comes from issues; the checkbox AC is the source of truth.
```

Plus a per-project **architecture map** and **gotchas** section (filled in
when a project is stamped — leave clear TODO placeholders).

---

## 4. Supporting pieces

- **`.github/ISSUE_TEMPLATE/spec.md`** — pre-fills the `Epic: #` line and an
  empty `### Acceptance criteria` checklist so even human-filed issues match
  the format the skills expect.
- **`.github/workflows/ci.yml`** — runs `<runner> check` on push + PR.
  Document the GitHub-token `workflow` scope gotcha (FieldLens hit this:
  pushing a workflow file needs `gh auth refresh -s workflow`).
- **`.claude/settings.json`** — allowlist the read-only + check commands so
  AFK agents don't stall on permission prompts (mirror FieldLens's allowlist;
  the `fewer-permission-prompts` skill can extend it from real transcripts).
- **`scripts/setup-labels.sh`** — idempotent `gh label create` for
  `epic` / `spec` / `backlog`.
- **`scripts/new-project.sh`** — copies a chosen `templates/<stack>`, inits
  git, creates the GitHub repo, runs `setup-labels.sh`, seeds `docs/`.

---

## 5. Recommended tools / MCPs (document in WORKFLOW.md)

| Tool | Why it matters | Priority |
|---|---|---|
| **GitHub MCP** (official) | Line-level PR review comments for `verify`; richer than `gh` | High |
| `gh` CLI | Issue/PR/label CRUD; the baseline everything falls back to | Required |
| Preview MCP | Dynamic smoke tests in `verify` | Medium |
| Playwright/WebKit | Device-realistic E2E once a project has UI | Per-project |
| `fewer-permission-prompts` skill | Tighten the AFK allowlist from real runs | Low |

---

## 6. Build order for the fresh session

1. `git init` the `agent-factory` repo; create it on GitHub (private).
2. Write `CLAUDE.md` (§3) and `docs/adr/ADR-0001-agentic-workflow.md`
   recording why this pipeline exists (cite FieldLens as the proving ground).
3. Build the five skills (§2) — these are the product. Test each skill's
   description triggers correctly.
4. Add `.github/` templates + CI; `.claude/settings.json`; `scripts/`.
5. Build the `templates/node-ts` starter mirroring FieldLens tooling (strict
   TS, vitest, eslint, the `check` script). Stub other stacks as backlog.
6. Write `README.md` (how to "Use this template") and `docs/WORKFLOW.md`
   (the human guide + the diagram from this file's §0).
7. **Dogfood it:** use the repo's own `/spec` skill to file its remaining
   backlog as issues — proves the machinery works on itself.
8. Mark the GitHub repo as a **template** (`gh repo edit --template`).

## 7. Acceptance criteria for the bootstrap itself

- [ ] `agent-factory` repo exists on GitHub, marked as a template.
- [ ] Five skills present with triggering descriptions and full procedures.
- [ ] CLAUDE.md encodes the agentic-mode rules and the single `check` gate.
- [ ] Issue + PR templates enforce the `Epic:` link + AC checklist format.
- [ ] CI runs `check` on push/PR; label setup script works.
- [ ] `node-ts` template builds green out of the box (`check` passes).
- [ ] `new-project.sh` produces a working, committed starter project.
- [ ] WORKFLOW.md explains the pipeline end-to-end with the §0 diagram.
- [ ] The repo dogfoods `/spec` to file its own remaining backlog.

---

### Appendix: the pipeline at a glance

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

Reference implementation: `paulcullin/fieldlens`.
```
