// Entry point. Keep the pure core in its own modules (see greet.ts) and wire
// side effects (IO, logging) here at the edge.
import { greet } from './greet.js';

function main(): void {
  console.log(greet('world'));
}

main();
