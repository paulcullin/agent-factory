# agent-factory

A **GitHub template repository** that stamps out new software projects
pre-wired for AFK ("away from keyboard") agentic development with Claude Code.

It takes a product idea and carries it autonomously through:

> **idea → PRD/spec → GitHub backlog → parallel implementation in isolated
> worktrees → eval/verify against acceptance criteria → merge & cleanup.**

The product is **not application code** — it's language-agnostic scaffolding:
a set of Claude Code **skills** + **conventions** + **CI**, with one worked
stack example (`node-ts`). The pattern was proven on
[FieldLens](https://github.com/paulcullin/fieldlens).

## What you get

- **Five composable skills** (`.claude/skills/`):
  | Skill | Does |
  |---|---|
  | `/spec <idea>` | idea → Epic + spec issues with acceptance criteria |
  | `/implement <#>` | issue → PR in an isolated git worktree |
  | `/verify <#>` | PR → AC-graded review (the eval) |
  | `/ship <#>` | merge an approved, CI-green PR + clean up |
  | `/sprint [N]` | orchestrate N issues through the pipeline in parallel |

  Plus a sixth, one-time bootstrap skill: **`/onboard`** — interviews you to
  finish wiring `CLAUDE.md` after adopting into an existing project (see
  Option C below), including scoping to one package in a monorepo.
- **`CLAUDE.md`** — the agentic working agreement (the single `check` gate, AC
  = spec, one worktree per issue, no force-push, 5-iteration cap).
- **Choice of issue tracker.** All five skills read/write GitHub Issues by
  default; set `issue_tracker: jira` in `CLAUDE.md` and they drive Epics and
  Stories in Jira instead, via the Atlassian MCP (Epic/Story creation, AC
  retrieval, comments, and status transitions).
- **Issue + PR templates** that enforce the `Epic:` link and `- [ ]` AC format.
- **CI** (`.github/workflows/ci.yml`) that runs the `check` gate on push/PR.
- **A proven stack starter** (`templates/node-ts/`) — strict TS, Vitest, ESLint,
  green out of the box.
- **Scripts** — `setup-labels.sh` and `new-project.sh`.

## Use this template

**Option A — GitHub UI:** click **“Use this template”**, then in your new repo
run `scripts/setup-labels.sh` and start with `/spec <your idea>`.

**Option B — script (new project):**

```bash
scripts/new-project.sh my-app --stack node-ts        # public + GitHub repo
scripts/new-project.sh my-app --stack node-ts --private
scripts/new-project.sh my-app --stack node-ts --no-remote   # local only
```

Then:

```bash
cd my-app
npm install
npm run check        # the single gate — typecheck + lint + test + build
```

**Option C — adopt into an existing project (including monorepos):** drop the
workflow into a repo you already have, non-destructively (never overwrites
your code, CI, or `CLAUDE.md`):

```bash
# from the root of your existing project
/path/to/agent-factory/scripts/adopt.sh
```

Then restart Claude Code and run **`/onboard`** — it interviews you to finish
wiring `CLAUDE.md` (the real `check` gate, architecture map, gotchas, issue
tracker) instead of you merging it by hand. In a monorepo, run it from inside
the package you want to scope the workflow to; it's re-runnable per package.
Full guide: **[docs/ADOPTING.md](docs/ADOPTING.md)**.

## The workflow

See **[docs/WORKFLOW.md](docs/WORKFLOW.md)** for the end-to-end guide and the
pipeline diagram. The rationale is recorded in
**[docs/adr/ADR-0001-agentic-workflow.md](docs/adr/ADR-0001-agentic-workflow.md)**.

### Design principles (non-negotiable)

1. **One verification gate** — `<runner> check` is the sole correctness arbiter.
2. **Acceptance criteria are the spec** — `- [ ]` checkboxes; no AC = no work.
3. **Isolation per unit of work** — one worktree + branch per issue.
4. **Docs accumulate** — context log + ADRs are part of every change.
5. **Deterministic before AI** — `check` gates correctness; AI verify gates AC
   *coverage*.

## Requirements

- [`gh` CLI](https://cli.github.com/), authenticated (required — GitHub mode's
  portable baseline; every skill works through it even without an MCP).
- GitHub MCP (recommended — line-level review comments for `/verify`).
- Atlassian MCP (required, no CLI fallback, only when `issue_tracker: jira`).
- Node 20+ for the `node-ts` stack.

> **Gotcha:** pushing `.github/workflows/*.yml` needs the `workflow` token
> scope — run `gh auth refresh -s workflow` if a push is rejected.
