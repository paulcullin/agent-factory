# Adopting agent-factory into an existing project

`new-project.sh` stamps a *fresh* repo. This guide is the other path: bringing
the agentic workflow into a project you **already have** — with its own code,
CI, and history — without disturbing any of it.

The product you're adopting is just scaffolding:

- the five skills (`.claude/skills/`) — the actual workflow,
- the working agreement (`CLAUDE.md`),
- issue + PR templates that enforce the `Epic:` link and `- [ ]` AC format,
- the workflow docs.

None of that is application code, so it layers onto an existing project cleanly.

## The fast path

From the root of your existing project:

```bash
/path/to/agent-factory/scripts/adopt.sh
```

or point it at a project and also create the labels:

```bash
/path/to/agent-factory/scripts/adopt.sh /path/to/your/project --labels
```

`adopt.sh` is **non-destructive**: it never overwrites a file you already have.
Where a merge is genuinely needed it writes a `*.agent-factory` reference copy
next to yours instead of clobbering. It does **not** touch git history, your CI,
or create a remote — those already exist. Read its output: every file it adds
(`+`), skips (`- exists`), or leaves a reference for (`~`) is printed.

## What lands, and what's left to finish

| Piece | Behavior | Your follow-up |
|---|---|---|
| `.claude/skills/*` (six, including `onboard`) | Added if absent (per skill) | None — these are the product |
| `.claude/settings.json` | Added if absent; else `settings.agent-factory.json` written | Merge the allowlist entries you want into yours |
| `CLAUDE.md` | Added if absent; else `CLAUDE.agent-factory.md` written | Run `/onboard` (see below) — it does the merge |
| `.github/ISSUE_TEMPLATE/*`, `PULL_REQUEST_TEMPLATE.md` | Added if absent | If you have your own, fold in the `Epic:`/`Touches:`/AC structure |
| `docs/WORKFLOW.md`, `docs/ADOPTING.md`, `docs/adr/ADR-0000-template.md` | Added if absent | None |
| `docs/00-context.md` | Seeded if absent | Keep appending to it |
| CI | **Not touched** | Ensure CI runs your single `check` gate (see below) |
| Labels | Only with `--labels`, or via `/onboard` | Otherwise run `scripts/setup-labels.sh` yourself |

### 1. Restart Claude Code

Claude Code enumerates skills at startup, so after `adopt.sh` runs, **relaunch
`claude` in the project** before the six skills (including `onboard`) appear in
`/skills` and become invocable.

### 2. Run `/onboard` — it finishes the wiring for you

`adopt.sh` is deliberately mechanical: it lands files and stops. `/onboard` is
the interview that finishes the job — it reads your repo (workspace tooling,
`package.json` scripts, README/CONTRIBUTING, any existing `CLAUDE.md`) and
infers what it can, asking only what it can't:

- **Merges `CLAUDE.md`.** If your project already had one, `adopt.sh` left it
  alone and wrote `CLAUDE.agent-factory.md` beside it. `/onboard` folds the
  reference copy's **Commands** / **Agentic mode** / **Conventions** sections
  into yours (or writes a fresh nested `CLAUDE.md` for monorepo scoping — see
  below), then deletes the reference. You confirm before anything is written.
- **Wires the real `check` gate.** The whole workflow hinges on one command
  that runs **typecheck + lint + test + build** and is the sole arbiter of
  correctness. `/onboard` reads your existing scripts, proposes one command
  (reusing an existing `check` script if you have one, composing it from
  lint/typecheck/test/build otherwise), and asks you to confirm or edit it
  before writing it into `CLAUDE.md`. It does **not** touch your CI — use the
  template's `.github/workflows/ci.yml` as a reference and make CI run that
  same command, so "green in CI" == "green locally."
- **Fills Architecture map and Gotchas** from what it can observe in your
  source layout, with you correcting anything it gets wrong.
- **Sets up labels** (`scripts/setup-labels.sh`) or, if you tell it your
  backlog lives in Jira, asks for `jira_site` and `jira_project_key`, sets
  `issue_tracker: jira` in `CLAUDE.md`, and confirms the **Atlassian MCP** is
  connected (a hard requirement in `jira` mode — no CLI fallback, see
  `CLAUDE.md` → Conventions).

Once it's done, start with `/spec <an idea>`.

### Monorepos — scoping to one package

If your repo is a monorepo, `/onboard` defaults to scoping the workflow to
**one package**, not the whole repo — its own `check` gate, its own worktrees,
its own acceptance-criteria boundary. Run `/onboard` from inside the package
directory (e.g. `apps/foo`) and it will:

- Write a **nested `apps/foo/CLAUDE.md`** rather than touching the repo root's
  own `CLAUDE.md` — Claude Code loads directory-local `CLAUDE.md` files for
  work done under that path, so this composes with your monorepo's existing
  conventions instead of overriding them.
- Set `## Monorepo scope` in that nested file: `monorepo: true`,
  `package_path: apps/foo`, and (GitHub mode) a `package_label` like `pkg:foo`
  used to scope issue selection/creation on a shared, repo-wide tracker.
  `/spec`, `/implement`, and `/sprint` all read this section and stay inside
  the package's boundary.
- Bring in **another package later** by re-running `/onboard` from inside its
  directory — each package gets its own nested `CLAUDE.md` and its own scope.

## Adopting only part of it

The pieces are independent. Common subsets:

- **Skills only:** copy `.claude/skills/` and add a `Commands` + `Agentic mode`
  section to your `CLAUDE.md`. Skip the templates and labels until you want the
  issue/PR enforcement.
- **Conventions only (no skills yet):** take `CLAUDE.md` + the issue/PR
  templates to standardize how work is specced and reviewed, and drive the
  pipeline manually.

Adopt incrementally; nothing here requires the whole set at once.
