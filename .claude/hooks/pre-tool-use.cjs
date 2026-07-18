#!/usr/bin/env node
// Claude PreToolUse Hook adapter. Shared guard logic lives in ../../hooks/pre-tool-use-core.cjs.

const fs = require('fs');
const { recordHookMetric } = require('./hook-metrics.cjs');
const {
  evaluatePreToolUse,
  formatPreToolUseOutput
} = require('../../hooks/pre-tool-use-core.cjs');

const hookStartTime = Date.now();

let input = {};
try {
  const raw = fs.readFileSync(0, 'utf8');
  input = raw ? JSON.parse(raw) : {};
} catch {
  process.stdout.write('{}');
  process.exit(0);
}

const cwd = input.cwd || process.cwd();
const decision = evaluatePreToolUse(input, { runtime: 'claude' });
const output = formatPreToolUseOutput(decision, 'claude');

recordHookMetric({
  hook: 'PreToolUse',
  startTime: hookStartTime,
  cwd,
  outputBytes: Buffer.byteLength(output || '', 'utf8'),
  mode: decision.action === 'block' ? 'block' : decision.action,
  selectedSkills: []
});

process.stdout.write(output);
