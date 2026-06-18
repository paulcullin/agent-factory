# node-ts starter

The proven stack template for agent-factory, mirroring FieldLens tooling:
strict TypeScript, Vitest, ESLint, and a single `check` gate.

## The gate

```bash
npm install
npm run check   # typecheck + lint + test + build — the sole arbiter of "safe"
```

CI runs exactly this on every push and PR. Agents loop against it.

## Layout

```
src/
  index.ts        # entry point — wire side effects (IO) here at the edge
  greet.ts        # pure core: testable, no IO
  greet.test.ts   # colocated test (new core logic requires one)
```

## Conventions

- Keep a pure, testable core; push side effects to the edges.
- Tests are colocated (`*.test.ts`); new core logic requires a test.
- `npm run check` must be green before any change is declared done.
