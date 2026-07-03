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

## What lands, and what you must finish by hand

| Piece | Behavior | Your follow-up |
|---|---|---|
| `.claude/skills/*` | Added if absent (per skill) | None — these are the product |
| `.claude/settings.json` | Added if absent; else `settings.agent-factory.json` written | Merge the allowlist entries you want into yours |
| `CLAUDE.md` | Added if absent; else `CLAUDE.agent-factory.md` written | **Merge** (see below) — this is the important one |
| `.github/ISSUE_TEMPLATE/*`, `PULL_REQUEST_TEMPLATE.md` | Added if absent | If you have your own, fold in the `Epic:`/`Touches:`/AC structure |
| `docs/WORKFLOW.md`, `docs/ADOPTING.md`, `docs/adr/ADR-0000-template.md` | Added if absent | None |
| `docs/00-context.md` | Seeded if absent | Keep appending to it |
| CI | **Not touched** | Ensure CI runs your single `check` gate (see below) |
| Labels | Only with `--labels` | Otherwise run `scripts/setup-labels.sh` yourself |

### 1. Merge `CLAUDE.md` (the one step that matters most)

If your project already has a `CLAUDE.md`, adoption leaves it alone and writes
`CLAUDE.agent-factory.md` beside it. Merge these sections from the reference
copy into yours, then delete the reference:

- **Commands** — set `<runner> check` to your project's *real* single gate
  command (e.g. `make check`, `pnpm check`, `cargo test`, `npm run check`).
- **Agentic mode** — the AC-is-spec rule, one-worktree-per-issue, no force-push,
  the 5-iteration cap, comment-and-stop on ambiguity.
- **Conventions** — colocated tests, pure core, docs-as-part-of-the-change, the
  deterministic-before-AI rule, and the GitHub MCP-vs-`gh` preference.

Also fill in the **Architecture map** and **Gotchas** sections with your
project's reality — that's what makes the skills effective on your codebase.

### 2. Make the single `check` gate real

The whole workflow hinges on one command that runs **typecheck + lint + test +
build** and is the sole arbiter of correctness. An existing project usually has
the pieces already — wire them into one entry point:

- Add a `check` script/target that chains them (so `/implement` and `/verify`
  have one thing to run).
- Make your CI run that **same** command, so "green in CI" == "green locally."

`adopt.sh` deliberately does **not** copy `ci.yml` over your CI. Use the
template's `.github/workflows/ci.yml` as a reference, but adapt it — your stack
and existing pipeline win.

### 3. Labels

The skills file issues with `epic` / `spec` / `backlog` labels. Create them:

```bash
scripts/setup-labels.sh            # uses the current repo's remote
scripts/setup-labels.sh owner/repo # or target an explicit repo
```

### 4. (Optional) Switch to Jira as the issue tracker

By default the skills read and write GitHub Issues. If your backlog lives in
Jira instead, one-time setup is:

1. In your merged `CLAUDE.md`, set `issue_tracker: jira` and fill in
   `jira_site` (your Atlassian Cloud site URL) and `jira_project_key` (e.g.
   `PROJ`) — see `CLAUDE.md` → Issue tracker in the reference copy.
2. Confirm the **Atlassian MCP server** is connected in your Claude Code
   session. Unlike GitHub, there's no `gh`-equivalent CLI fallback for Jira,
   so this is a hard requirement in `jira` mode (documented as an explicit
   exception in `CLAUDE.md` → Conventions) — no `scripts/setup-labels.sh`-style
   script is needed, since Jira's Epic/Story issue types are native and don't
   need to be created.

That's it — no other file changes; the skills themselves branch on
`issue_tracker` at run time.

### 5. Restart Claude Code

Claude Code enumerates skills at startup, so after adoption **relaunch `claude`
in the project** before the five skills appear in `/skills` and become
invocable. Then start with `/spec <an idea>`.

## Adopting only part of it

The pieces are independent. Common subsets:

- **Skills only:** copy `.claude/skills/` and add a `Commands` + `Agentic mode`
  section to your `CLAUDE.md`. Skip the templates and labels until you want the
  issue/PR enforcement.
- **Conventions only (no skills yet):** take `CLAUDE.md` + the issue/PR
  templates to standardize how work is specced and reviewed, and drive the
  pipeline manually.

Adopt incrementally; nothing here requires the whole set at once.
