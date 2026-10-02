#!/usr/bin/env node
'use strict';

function stripJsonc(text) {
  let out = '';
  let inString = false;
  let stringQuote = '';
  let escaped = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const next = i + 1 < text.length ? text[i + 1] : '';

    if (inLineComment) {
      if (ch === '\n') {
        inLineComment = false;
        out += ch;
      }
      continue;
    }

    if (inBlockComment) {
      if (ch === '*' && next === '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }

    if (inString) {
      out += ch;
      if (escaped) {
        escaped = false;
      } else if (ch === '\\') {
        escaped = true;
      } else if (ch === stringQuote) {
        inString = false;
        stringQuote = '';
      }
      continue;
    }

    if (ch === '/' && next === '/') {
      inLineComment = true;
      i++;
      continue;
    }

    if (ch === '/' && next === '*') {
      inBlockComment = true;
      i++;
      continue;
    }

    if (ch === '"' || ch === '\'') {
      inString = true;
      stringQuote = ch;
      out += ch;
      continue;
    }

    out += ch;
  }

  return out;
}

function removeTrailingCommas(text) {
  let previous = null;
  let current = text;
  const trailingCommaPattern = /,\s*([}\]])/g;
  while (current !== previous) {
    previous = current;
    current = current.replace(trailingCommaPattern, '$1');
  }
  return current;
}

function parseJsonc(text) {
  const sanitized = removeTrailingCommas(stripJsonc(text));
  return JSON.parse(sanitized);
}

function collectOutputPaths(node, results) {
  if (Array.isArray(node)) {
    for (const item of node) {
      collectOutputPaths(item, results);
    }
    return;
  }

  if (!node || typeof node !== 'object') {
    return;
  }

  if (Array.isArray(node.paths)) {
    for (const item of node.paths) {
      if (typeof item === 'string') {
        results.push(item);
      }
    }
  }

  for (const value of Object.values(node)) {
    collectOutputPaths(value, results);
  }
}

function createSeed(seedText) {
  let hash = 2166136261;
  for (let i = 0; i < seedText.length; i++) {
    hash ^= seedText.charCodeAt(i);
    hash = Math.imul(hash, 16777619) >>> 0;
  }
  return hash >>> 0;
}

function createRng(seed) {
  let state = seed >>> 0;
  return function next() {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function sampleDeterministically(items, limit, seedText) {
  const ordered = [...items].sort();
  if (ordered.length <= limit) {
    return ordered;
  }

  const rng = createRng(createSeed(seedText));
  const working = [...ordered];
  for (let i = working.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    const tmp = working[i];
    working[i] = working[j];
    working[j] = tmp;
  }
  return working.slice(0, limit).sort();
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 1 || args.length > 2) {
    console.error('usage: node sample-output-paths.js VALUES_FILE [MAX_COUNT]');
    process.exit(2);
  }

  const fs = require('fs');
  const path = require('path');

  const valuesFile = args[0];
  const maxCount = args[1] ? parseInt(args[1], 10) : 100;
  if (!Number.isInteger(maxCount) || maxCount <= 0) {
    console.error('MAX_COUNT must be a positive integer');
    process.exit(2);
  }

  const raw = fs.readFileSync(valuesFile, 'utf8');
  const parsed = parseJsonc(raw);
  const allPaths = [];

  if (Array.isArray(parsed.forms)) {
    for (const form of parsed.forms) {
      if (form && typeof form === 'object' && form.outputs) {
        collectOutputPaths(form.outputs, allPaths);
      }
    }
  }

  const uniquePaths = Array.from(new Set(allPaths));
  console.log(`TOTAL_PATHS=${uniquePaths.length}`);

  if (uniquePaths.length === 0) {
    return;
  }

  const sample = sampleDeterministically(uniquePaths, maxCount, path.resolve(valuesFile));
  for (const item of sample) {
    console.log(item);
  }
}

main();
