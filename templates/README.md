# Stack templates

Each subdirectory is a per-stack starter that `scripts/new-project.sh` can stamp
into a fresh project. Every stack must expose the **same contract** so the
skills and CI are stack-agnostic:

- A single **`check`** command that runs **typecheck + lint + test + build** and
  is the sole arbiter of correctness.
- A **pure, testable core** with **colocated tests**.
- Whatever config the gate needs, committed and green out of the box.

## Available stacks

| Stack | Status | Notes |
|---|---|---|
| `node-ts` | ✅ proven | Strict TS, Vitest, ESLint. Mirrors FieldLens tooling. |

## Adding a new stack

1. Create `templates/<stack>/` with the stack's own tooling.
2. Wire a `check` script/target that runs typecheck + lint + test + build.
3. Include one pure-core module with a colocated test so `check` is green on a
   fresh stamp.
4. Make sure `.github/workflows/ci.yml` (copied by `new-project.sh`) can run the
   gate — adjust the CI steps if the stack isn't Node-based.
5. Add a row to the table above.

> Keep each starter minimal: it should demonstrate the conventions, not be a
> full app. The product is the workflow, not the example code.
