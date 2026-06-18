import { describe, expect, it } from 'vitest';
import { greet } from './greet.js';

describe('greet', () => {
  it('greets a given name', () => {
    expect(greet('Ada')).toBe('Hello, Ada!');
  });

  it('trims surrounding whitespace', () => {
    expect(greet('  Ada  ')).toBe('Hello, Ada!');
  });

  it('falls back to "world" when the name is empty', () => {
    expect(greet('')).toBe('Hello, world!');
    expect(greet('   ')).toBe('Hello, world!');
  });
});
