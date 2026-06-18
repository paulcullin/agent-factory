// Pure core: no IO, fully testable. This is the kind of module new logic
// should live in — see greet.test.ts for the colocated test.

/**
 * Build a greeting for the given name. Trims surrounding whitespace and falls
 * back to "world" when the name is empty.
 */
export function greet(name: string): string {
  const trimmed = name.trim();
  const who = trimmed.length > 0 ? trimmed : 'world';
  return `Hello, ${who}!`;
}
