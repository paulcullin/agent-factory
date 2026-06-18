# agent-factory — context log

_Append-only running notes. Newest at the bottom. This is the project's
narrative memory; every non-trivial change adds a line here._

## 2026-06-17 — template bootstrapped

- Built the agent-factory template per `BOOTSTRAP-BLUEPRINT.md`.
- Five skills authored under `.claude/skills/`: spec, implement, verify, ship,
  sprint. These are the actual product.
- CLAUDE.md encodes the agentic working agreement (single `check` gate, AC =
  spec, one worktree per issue, no force-push, 5-iteration cap).
- `.github/` issue + PR templates enforce the `Epic:` link + AC checklist.
- CI (`ci.yml`) runs `npm run check` on push/PR.
- `templates/node-ts/` is the proven stack starter (strict TS, vitest, eslint,
  the `check` script). Other stacks deferred to backlog.
- Scripts: `setup-labels.sh` (idempotent labels), `new-project.sh` (stamp a
  project).
- Decision recorded in `docs/adr/ADR-0001-agentic-workflow.md`.

## 2026-06-17 — published + dogfooded

- Repo created on GitHub as **private** and marked as a **template**
  (`paulcullin/agent-factory`). Pushed over HTTPS (SSH host-key verification
  was unavailable in the build env).
- Labels `epic`/`spec`/`backlog` created via `setup-labels.sh`.
- Hardened `ci.yml`: the template repo has no root `package.json`, so the
  `check` job no-ops there while a new `templates` job runs the `node-ts`
  gate. Both jobs go green in CI; verified the `templates` job actually runs
  `npm run check`.
- Dogfooded `/spec`: filed Epic #1 + spec issues #2–#5 (python stack, go stack,
  Preview MCP smoke test, GitHub MCP setup) — proves the machinery on itself.
