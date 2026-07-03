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

## 2026-06-18 — GitHub MCP-vs-`gh` convention made explicit

- Made the "prefer GitHub MCP, fall back to `gh`" rule a documented convention
  rather than a one-off in `/verify`. Added it to `CLAUDE.md` → Conventions and
  the `docs/WORKFLOW.md` tools table.
- Rationale: `gh` stays the required, portable baseline because it's the only
  option in `scripts/` and CI and must not become a hard MCP dependency; MCP is
  preferred where it's richer (esp. line-level inline review comments). Skills
  keep their `gh` form unchanged.

## 2026-06-18 — adoption path for existing projects

- Added `scripts/adopt.sh`: non-destructively layers the shared machinery
  (skills, CLAUDE.md, issue/PR templates, workflow docs) into an existing repo.
  Never overwrites; writes `*.agent-factory` reference copies for files that
  need a manual merge (CLAUDE.md, settings.json). Doesn't touch git, CI, or
  remotes. `--labels` opt-in for setup-labels.sh. Verified end-to-end against a
  simulated existing repo: existing files preserved, idempotent on re-run.
- Added `docs/ADOPTING.md` (full guide, incl. partial-adoption subsets) and a
  README "Option C — adopt into an existing project".

## 2026-07-03 — Jira config contract (issue #7, epic #6)

- Added `issue_tracker: github|jira` (plus `jira_site`/`jira_project_key`) to
  `CLAUDE.md` — the shared switch the five skills will branch on to support
  Jira as an alternative backlog to GitHub Issues.
- Documented an explicit exception in `CLAUDE.md` → Conventions: in `jira`
  mode the Atlassian MCP is a hard dependency with no CLI fallback, unlike the
  GitHub MCP-vs-`gh` rule — there's no Jira CLI as ubiquitous as `gh` to fall
  back to.
- Added the Atlassian MCP row to the `docs/WORKFLOW.md` tools table and a
  Jira-mode setup subsection to `docs/ADOPTING.md`.
- This is the shared contract for the five skill-specific Jira issues
  (#8–#12) under epic #6; it doesn't itself change any skill's procedure.
- **Shipped:** PR #13 merged to `main` at `599f53d`, closing issue #7.
  Merged manually (not via `/ship`'s `--squash`) since `gh` couldn't post an
  approving review under `/verify` — same identity authored and verified the
  PR, and GitHub blocks self-approval. Grading was posted as a PR comment
  instead; a human approved the merge itself. That gap prompted two follow-up
  edits landed straight to `main` (not through a PR): `CLAUDE.md` → Gotchas
  now documents the self-approval block, and `/verify`'s procedure now checks
  PR-author-vs-authenticated-identity up front and skips straight to the
  comment fallback instead of attempting and failing `--approve`.
  Worktree `.claude/worktrees/issue-7` and branch `worktree-issue-7` (local +
  remote) removed.

## 2026-07-03 — Jira backend for /ship (issue #11, epic #6)

- `.claude/skills/ship/SKILL.md` step 4 ("Confirm issue closure") now forks on
  `issue_tracker`: `github` mode is unchanged (rely on `Closes #<#>`
  auto-close); `jira` mode resolves the Jira key from the PR body's
  `Jira: <JIRA-KEY>` line, transitions it to Done via the Atlassian MCP, and
  comments the merge SHA + PR URL. Guard, merge, and serialization rules are
  unchanged and tracker-agnostic.

## 2026-07-03 — Jira backend for /sprint (issue #12, epic #6)

- `/sprint` step 1 ("Select work") now forks on `issue_tracker`: `github`
  unchanged (`gh issue list --label spec --state open`); `jira` queries
  `jira_project_key` for open Story-type issues via the Atlassian MCP,
  ordered by priority. N=3 default / ~5 ceiling unchanged either way.
- Step 6 ("Summarize") now reports Jira keys instead of issue numbers in the
  Shipped/Blocked/Still-running buckets when `issue_tracker: jira`.
- Steps 2–5 left untouched per AC — they already compose `/spec`, `/implement`,
  `/verify`, `/ship`, each carrying its own tracker fork.

## 2026-07-03 — Jira backend for /verify (issue #10, epic #6)

- Added a `jira`-mode fork to `.claude/skills/verify/SKILL.md`: step 1 resolves
  AC from the Jira key on the PR body's `Jira: <JIRA-KEY>` line (via the
  Atlassian MCP) instead of `gh pr view --json closingIssuesReferences`; AC
  grading itself is unchanged.
- Step 6 now additionally posts the `## AC grade` / `## Verdict` summary as a
  Jira comment and, on request-changes, transitions the Jira issue back to an
  "in progress"-style status. The existing GitHub-side review (incl. the
  self-approval-identity check) is untouched.

## 2026-07-03 — Jira backend for /implement (issue #9, epic #6)

- `.claude/skills/implement/SKILL.md` now forks on `issue_tracker`: `jira`
  mode reads AC from the Jira issue via the Atlassian MCP, branches as
  `feature/<jira-key>`, and opens the PR (still on GitHub) with a
  `Jira: <JIRA-KEY>` line instead of `Closes #<#>`.
- After the PR opens, `jira` mode posts the PR URL as a Jira comment and
  attempts an "in progress"-style transition via the Atlassian MCP.
- The ambiguous-AC stop rule, the 5-iteration `check` cap, and the
  never-force-push/never-merge-here invariants are unchanged and
  tracker-agnostic across both modes.

## 2026-07-03 — `/spec` gains a Jira backend (issue #8, epic #6)

- `.claude/skills/spec/SKILL.md` now forks on `issue_tracker`: `github` mode
  is unchanged (`gh issue create`); `jira` mode creates the Epic and each
  spec Story via the Atlassian MCP (discovered via `ToolSearch`), scoped to
  `jira_project_key`, with `Epic: <JIRA-KEY>` back-links and the same
  `Touches:` line + `### Acceptance criteria` bar as GitHub mode.
- Returns Jira issue keys (e.g. `PROJ-101`) in place of GitHub numbers when in
  `jira` mode, for `/sprint` or the user to hand off.
- **This closes out epic #6** — all five skills (`spec`, `implement`, `verify`,
  `ship`, `sprint`) now carry a `jira`-mode fork alongside their `github`
  behavior, gated by the shared `issue_tracker` config from issue #7.
