import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { compilePrompt, examplePrompt, getPrompt, isPromptName } from './index.js';

describe('compilePrompt', () => {
  it('substitutes a single variable', () => {
    assert.equal(compilePrompt('Hello {{name}}!', { name: 'World' }), 'Hello World!');
  });

  it('substitutes multiple variables', () => {
    assert.equal(compilePrompt('{{a}} and {{b}}', { a: 'X', b: 'Y' }), 'X and Y');
  });

  it('substitutes repeated placeholders everywhere', () => {
    assert.equal(compilePrompt('{{x}}-{{x}}-{{x}}', { x: 'v' }), 'v-v-v');
  });

  it('leaves unknown placeholders untouched', () => {
    assert.equal(compilePrompt('Hello {{name}}!', { other: 'x' }), 'Hello {{name}}!');
  });

  it('ignores variables that have no placeholder in the template', () => {
    assert.equal(compilePrompt('static text', { unused: 'x' }), 'static text');
  });

  it('returns the template unchanged when variables are omitted', () => {
    assert.equal(compilePrompt('Hello {{name}}!'), 'Hello {{name}}!');
  });

  it('returns the template unchanged for an empty variables object', () => {
    assert.equal(compilePrompt('Hello {{name}}!', {}), 'Hello {{name}}!');
  });

  it('substitutes empty-string values', () => {
    assert.equal(compilePrompt('[{{gap}}]', { gap: '' }), '[]');
  });

  it('handles an empty template', () => {
    assert.equal(compilePrompt('', { a: 'x' }), '');
  });

  it('keeps dollar-sign replacement patterns literal in values', () => {
    // String replacements would interpret $&/$$/$' — the function form must not
    assert.equal(compilePrompt('Price: {{p}}', { p: '$100' }), 'Price: $100');
    assert.equal(compilePrompt('Match: {{m}}', { m: '$&' }), 'Match: $&');
    assert.equal(compilePrompt('Escaped: {{e}}', { e: '$$' }), 'Escaped: $$');
  });

  it('treats placeholder keys literally, not as regex', () => {
    assert.equal(compilePrompt('A {{a.b}} B', { 'a.b': 'dot' }), 'A dot B');
  });
});

describe('isPromptName', () => {
  it('accepts a registered prompt name', () => {
    assert.equal(isPromptName('example'), true);
  });

  it('rejects an unregistered name', () => {
    assert.equal(isPromptName('nonexistent'), false);
  });

  it('rejects an empty string', () => {
    assert.equal(isPromptName(''), false);
  });

  it('rejects inherited object property names', () => {
    // `name in registry` must not match Object.prototype members
    assert.equal(isPromptName('toString'), false);
    assert.equal(isPromptName('constructor'), false);
  });
});

describe('getPrompt', () => {
  it('returns a compiled registered prompt with wasFound: true', () => {
    const { text, name, wasFound } = getPrompt('example', { context: 'ctx', query: 'q' });
    assert.equal(wasFound, true);
    assert.equal(name, 'example');
    assert.ok(text.includes('Context: ctx'));
    assert.ok(text.includes('User Query: q'));
    assert.ok(!text.includes('{{'));
  });

  it('falls back to the example prompt for an unknown name', () => {
    const { text, name, wasFound } = getPrompt('nonexistent');
    assert.equal(wasFound, false);
    assert.equal(name, 'example');
    assert.equal(text, examplePrompt);
  });

  it('falls back for an empty-string name', () => {
    const { wasFound, name } = getPrompt('');
    assert.equal(wasFound, false);
    assert.equal(name, 'example');
  });

  it('applies variables to the fallback prompt too', () => {
    const { text, wasFound } = getPrompt('nonexistent', { context: 'ctx', query: 'q' });
    assert.equal(wasFound, false);
    assert.ok(text.includes('Context: ctx'));
  });

  it('leaves placeholders intact when variables are omitted', () => {
    const { text } = getPrompt('example');
    assert.ok(text.includes('{{context}}'));
    assert.ok(text.includes('{{query}}'));
  });
});
