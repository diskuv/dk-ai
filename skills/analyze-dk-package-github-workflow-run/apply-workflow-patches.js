#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

function usage() {
  console.error("usage: node apply-workflow-patches.js --checkout PATH --patch-root PATH [--patch-root PATH ...]");
  process.exit(2);
}

function parseArgs(argv) {
  const args = { patchRoots: [] };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--checkout") {
      args.checkout = argv[++i];
    } else if (arg === "--patch-root") {
      args.patchRoots.push(argv[++i]);
    } else {
      usage();
    }
  }
  if (!args.checkout || args.patchRoots.length === 0) {
    usage();
  }
  return args;
}

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8").replace(/\r\n/g, "\n");
}

function writeText(filePath, text) {
  fs.writeFileSync(filePath, text, "utf8");
}

function normalizePatchPath(rawPath) {
  let p = rawPath.trim();
  if (p === "/dev/null") {
    return null;
  }
  if (p.startsWith("a/") || p.startsWith("b/")) {
    p = p.slice(2);
  }
  if (p.endsWith(".actual")) {
    p = p.slice(0, -".actual".length);
  }
  return p;
}

function parseRange(value) {
  const parts = value.split(",");
  return {
    start: Number(parts[0]),
    count: parts.length === 2 ? Number(parts[1]) : 1,
  };
}

function parseHunk(header, bodyLines) {
  const match = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/.exec(header);
  if (!match) {
    throw new Error(`invalid hunk header: ${header}`);
  }
  const oldRange = parseRange(match[1] + (match[2] ? `,${match[2]}` : ""));
  const newRange = parseRange(match[3] + (match[4] ? `,${match[4]}` : ""));
  const oldLines = [];
  const newLines = [];

  for (const line of bodyLines) {
    if (line === "\\ No newline at end of file") {
      continue;
    }
    if (line.startsWith(" ")) {
      const value = line.slice(1);
      oldLines.push(value);
      newLines.push(value);
    } else if (line.startsWith("-")) {
      oldLines.push(line.slice(1));
    } else if (line.startsWith("+")) {
      newLines.push(line.slice(1));
    } else {
      throw new Error(`invalid hunk body line: ${line}`);
    }
  }

  return { oldRange, newRange, oldLines, newLines };
}

function parsePatch(text) {
  const lines = text.split("\n");
  const files = [];
  let i = 0;

  while (i < lines.length) {
    if (lines[i] === "") {
      i++;
      continue;
    }
    if (!lines[i].startsWith("--- ")) {
      i++;
      continue;
    }

    const oldPath = lines[i].slice(4).split("\t")[0].trim();
    i++;
    if (i >= lines.length || !lines[i].startsWith("+++ ")) {
      throw new Error(`missing +++ header after ${oldPath}`);
    }
    const newPath = lines[i].slice(4).split("\t")[0].trim();
    i++;

    const hunks = [];
    while (i < lines.length && !lines[i].startsWith("--- ")) {
      if (!lines[i].startsWith("@@ ")) {
        i++;
        continue;
      }
      const header = lines[i];
      i++;
      const bodyLines = [];
      while (i < lines.length && !lines[i].startsWith("@@ ") && !lines[i].startsWith("--- ")) {
        if (lines[i] === "") {
          i++;
          continue;
        }
        bodyLines.push(lines[i]);
        i++;
      }
      hunks.push(parseHunk(header, bodyLines));
    }

    files.push({ oldPath, newPath, hunks });
  }

  return files;
}

function splitLines(text) {
  if (text.length === 0) {
    return [];
  }
  const lines = text.replace(/\r\n/g, "\n").split("\n");
  if (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }
  return lines;
}

function findMatches(lines, needle) {
  if (needle.length === 0) {
    return [];
  }
  const matches = [];
  for (let i = 0; i <= lines.length - needle.length; i++) {
    let ok = true;
    for (let j = 0; j < needle.length; j++) {
      if (lines[i + j] !== needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) {
      matches.push(i);
    }
  }
  return matches;
}

function chooseBestMatch(matches, hint) {
  let best = null;
  for (const idx of matches) {
    const dist = Math.abs(idx - hint);
    if (best === null || dist < best.dist || (dist === best.dist && idx < best.idx)) {
      best = { idx, dist };
    }
  }
  return best;
}

function applyHunk(lines, hunk) {
  const hint = Math.max(0, hunk.oldRange.start - 1);
  const oldMatches = findMatches(lines, hunk.oldLines);
  const newMatches = findMatches(lines, hunk.newLines);
  const oldBest = chooseBestMatch(oldMatches, hint);
  const newBest = chooseBestMatch(newMatches, hint);

  if (!oldBest && !newBest) {
    return { lines, applied: false, skipped: false, failed: true, reason: `could not locate hunk near line ${hunk.oldRange.start}` };
  }

  const preferNew = newBest && (!oldBest || newBest.dist <= oldBest.dist);
  if (preferNew) {
    return { lines, applied: false, skipped: true, failed: false };
  }

  const idx = oldBest.idx;
  const next = lines.slice(0, idx).concat(hunk.newLines, lines.slice(idx + hunk.oldLines.length));
  return { lines: next, applied: true, skipped: false, failed: false };
}

function ensureCheckout(checkout) {
  execFileSync("git", ["-C", checkout, "rev-parse", "--git-dir"], { stdio: "ignore" });
  const dkU = path.join(checkout, "dk.u");
  if (!fs.existsSync(dkU)) {
    throw new Error(`missing dk.u in checkout root: ${checkout}`);
  }
}

function collectPatchFiles(roots) {
  const results = [];
  for (const root of roots) {
    if (!fs.existsSync(root)) {
      continue;
    }
    const stack = [root];
    while (stack.length > 0) {
      const current = stack.pop();
      for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
        const fullPath = path.join(current, entry.name);
        if (entry.isDirectory()) {
          stack.push(fullPath);
        } else if (entry.isFile() && entry.name.endsWith(".patch")) {
          const artifactMatch = /(?:^|[\\/])artifact-([^\\/]+)(?:[\\/]|$)/.exec(fullPath);
          results.push({
            path: fullPath,
            artifactId: artifactMatch ? artifactMatch[1] : null,
          });
        }
      }
    }
  }
  return results.sort((a, b) => a.path.localeCompare(b.path));
}

function applyPatchFile(checkout, patchFile) {
  const patch = parsePatch(readText(patchFile));
  const touched = [];
  const failed = [];
  let appliedHunks = 0;
  let skippedHunks = 0;
  let failedHunks = 0;

  for (const filePatch of patch) {
    const relPath = normalizePatchPath(filePatch.newPath) || normalizePatchPath(filePatch.oldPath);
    if (!relPath) {
      continue;
    }
    const absPath = path.join(checkout, relPath.split("/").join(path.sep));
    if (!fs.existsSync(absPath)) {
      throw new Error(`target file not found: ${relPath}`);
    }

    let lines = splitLines(readText(absPath));
    let changed = false;
    let fileApplied = 0;
    let fileSkipped = 0;
    let fileFailed = 0;

    for (const hunk of filePatch.hunks) {
      const result = applyHunk(lines, hunk);
      if (result.failed) {
        failedHunks++;
        fileFailed++;
        failed.push(`${relPath} (near line ${hunk.oldRange.start}): ${result.reason}`);
        continue;
      }
      lines = result.lines;
      if (result.applied) {
        changed = true;
        appliedHunks++;
        fileApplied++;
      } else {
        skippedHunks++;
        fileSkipped++;
      }
    }

    if (changed) {
      writeText(absPath, lines.join("\n") + "\n");
      touched.push(`${relPath} (+${fileApplied}, ~${fileSkipped}${fileFailed ? `, !${fileFailed}` : ""})`);
    } else if (fileApplied === 0 && fileSkipped > 0 && fileFailed === 0) {
      touched.push(`${relPath} (already applied)`);
    } else if (fileFailed > 0) {
      touched.push(`${relPath} (!${fileFailed}${fileSkipped ? `, ~${fileSkipped}` : ""})`);
    } else {
      touched.push(`${relPath} (unchanged)`);
    }
  }

  return { touched, failed, appliedHunks, skippedHunks, failedHunks };
}

function main() {
  const args = parseArgs(process.argv);
  const checkout = path.resolve(args.checkout);
  ensureCheckout(checkout);

  const patchFiles = collectPatchFiles(args.patchRoots.map((root) => path.resolve(root)));
  if (patchFiles.length === 0) {
    throw new Error("no .patch files found under the supplied patch roots");
  }

  let totalApplied = 0;
  let totalSkipped = 0;
  let totalFailed = 0;
  const changedFiles = [];
  const failedFiles = [];

  for (const patchFile of patchFiles) {
    const result = applyPatchFile(checkout, patchFile.path);
    totalApplied += result.appliedHunks;
    totalSkipped += result.skippedHunks;
    totalFailed += result.failedHunks;
    changedFiles.push(...result.touched);
    failedFiles.push(...result.failed);
  }

  console.log("Patch files:");
  for (const patchFile of patchFiles) {
    const idText = patchFile.artifactId ? `artifact ${patchFile.artifactId}: ` : "";
    console.log(`- ${idText}${patchFile.path}`);
  }
  console.log(`Applied patch files: ${patchFiles.length}`);
  console.log(`Applied hunks: ${totalApplied}`);
  console.log(`Skipped hunks: ${totalSkipped}`);
  console.log(`Failed hunks: ${totalFailed}`);
  for (const line of changedFiles) {
    console.log(line);
  }
  for (const line of failedFiles) {
    console.log(line);
  }

  if (totalFailed > 0) {
    process.exitCode = 1;
  }
}

main();
