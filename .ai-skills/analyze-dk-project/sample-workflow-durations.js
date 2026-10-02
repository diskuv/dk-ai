#!/usr/bin/env node
'use strict';

function toMinutes(startIso, endIso) {
  if (!startIso || !endIso) {
    return null;
  }

  const start = Date.parse(startIso);
  const end = Date.parse(endIso);
  if (!Number.isFinite(start) || !Number.isFinite(end) || end < start) {
    return null;
  }

  const minutes = Math.round((end - start) / 60000);
  return Math.max(1, minutes);
}

function percentile(sortedItems, p) {
  if (sortedItems.length === 0) {
    return null;
  }
  const idx = Math.floor((sortedItems.length - 1) * p);
  return sortedItems[idx];
}

function main() {
  const args = process.argv.slice(2);
  if (args.length < 1 || args.length > 2) {
    console.error('usage: node sample-workflow-durations.js RUNS_JSON [RECENT_LIMIT]');
    process.exit(2);
  }

  const fs = require('fs');
  const runsPath = args[0];
  const recentLimit = args[1] ? parseInt(args[1], 10) : 5;
  if (!Number.isInteger(recentLimit) || recentLimit <= 0) {
    console.error('RECENT_LIMIT must be a positive integer');
    process.exit(2);
  }

  const raw = fs.readFileSync(runsPath, 'utf8');
  const parsed = JSON.parse(raw);
  const runs = Array.isArray(parsed) ? parsed : [];
  const tagPattern = /^\d+\.\d+\.\d{12}$/;

  const matched = [];
  for (const run of runs) {
    if (!run || typeof run !== 'object') {
      continue;
    }
    if (run.status !== 'completed' || run.conclusion !== 'success') {
      continue;
    }

    const headBranch = typeof run.headBranch === 'string' ? run.headBranch : '';
    const displayTitle = typeof run.displayTitle === 'string' ? run.displayTitle : '';
    if (!tagPattern.test(headBranch) && !displayTitle.startsWith('Release ')) {
      continue;
    }

    const startedAt = run.startedAt || run.createdAt;
    const endedAt = run.updatedAt;
    const durationMinutes = toMinutes(startedAt, endedAt);
    if (durationMinutes === null) {
      continue;
    }

    matched.push({
      durationMinutes,
      headBranch,
      workflowName: typeof run.workflowName === 'string' ? run.workflowName : '(unknown workflow)',
      url: typeof run.url === 'string' ? run.url : '',
      endedAt: typeof endedAt === 'string' ? endedAt : '',
    });
  }

  matched.sort((a, b) => a.durationMinutes - b.durationMinutes);
  const durations = matched.map((item) => item.durationMinutes);
  const sampleCount = durations.length;
  const min = sampleCount > 0 ? durations[0] : null;
  const max = sampleCount > 0 ? durations[sampleCount - 1] : null;
  const median = percentile(durations, 0.5);
  const p80 = percentile(durations, 0.8);
  const expected = median;

  console.log(`SAMPLE_COUNT=${sampleCount}`);
  console.log(`EXPECTED_DURATION_MINUTES=${expected === null ? 'NA' : expected}`);
  console.log(`MIN_DURATION_MINUTES=${min === null ? 'NA' : min}`);
  console.log(`MAX_DURATION_MINUTES=${max === null ? 'NA' : max}`);
  console.log(`MEDIAN_DURATION_MINUTES=${median === null ? 'NA' : median}`);
  console.log(`P80_DURATION_MINUTES=${p80 === null ? 'NA' : p80}`);

  const recent = matched
    .slice()
    .sort((a, b) => String(b.endedAt).localeCompare(String(a.endedAt)))
    .slice(0, recentLimit);
  for (const item of recent) {
    console.log(`RECENT_RUN=${item.headBranch}|${item.workflowName}|${item.durationMinutes}|${item.url}`);
  }
}

main();
