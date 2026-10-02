#!/usr/bin/env python3
from __future__ import annotations

import json
import pathlib
import re
import sys
from datetime import datetime
from typing import Any


def parse_iso8601(value: str | None) -> datetime | None:
    if not value or not isinstance(value, str):
        return None
    if value.endswith('Z'):
        value = value[:-1] + '+00:00'
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        return None


def to_minutes(start_iso: str | None, end_iso: str | None) -> int | None:
    start_dt = parse_iso8601(start_iso)
    end_dt = parse_iso8601(end_iso)
    if start_dt is None or end_dt is None or end_dt < start_dt:
        return None
    minutes = round((end_dt - start_dt).total_seconds() / 60.0)
    return max(1, minutes)


def percentile(sorted_items: list[int], p: float) -> int | None:
    if not sorted_items:
        return None
    index = int((len(sorted_items) - 1) * p)
    return sorted_items[index]


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print('usage: python sample-workflow-durations.py RUNS_JSON [RECENT_LIMIT]', file=sys.stderr)
        return 2

    runs_file = pathlib.Path(sys.argv[1])
    recent_limit = int(sys.argv[2]) if len(sys.argv) == 3 else 5
    if recent_limit <= 0:
        print('RECENT_LIMIT must be a positive integer', file=sys.stderr)
        return 2

    raw = runs_file.read_text(encoding='utf-8')
    parsed = json.loads(raw)
    runs = parsed if isinstance(parsed, list) else []

    matched: list[dict[str, Any]] = []
    for run in runs:
        if not isinstance(run, dict):
            continue
        if run.get('status') != 'completed' or run.get('conclusion') != 'success':
            continue

        head_branch = run.get('headBranch')
        display_title = run.get('displayTitle')
        is_release_tag = isinstance(head_branch, str) and bool(re.match(r'^\d+\.\d+\.\d{12}$', head_branch))
        is_release_title = isinstance(display_title, str) and display_title.startswith('Release ')
        if not (is_release_tag or is_release_title):
            continue

        started_at = run.get('startedAt') or run.get('createdAt')
        ended_at = run.get('updatedAt')
        duration_minutes = to_minutes(started_at, ended_at)
        if duration_minutes is None:
            continue

        matched.append(
            {
                'durationMinutes': duration_minutes,
                'headBranch': head_branch if isinstance(head_branch, str) else '',
                'workflowName': run.get('workflowName') if isinstance(run.get('workflowName'), str) else '(unknown workflow)',
                'url': run.get('url') if isinstance(run.get('url'), str) else '',
                'endedAt': ended_at if isinstance(ended_at, str) else '',
            }
        )

    matched.sort(key=lambda item: item['durationMinutes'])
    durations = [item['durationMinutes'] for item in matched]
    sample_count = len(durations)
    minimum = durations[0] if sample_count > 0 else None
    maximum = durations[-1] if sample_count > 0 else None
    median = percentile(durations, 0.5)
    p80 = percentile(durations, 0.8)
    expected = median

    print(f'SAMPLE_COUNT={sample_count}')
    print(f"EXPECTED_DURATION_MINUTES={'NA' if expected is None else expected}")
    print(f"MIN_DURATION_MINUTES={'NA' if minimum is None else minimum}")
    print(f"MAX_DURATION_MINUTES={'NA' if maximum is None else maximum}")
    print(f"MEDIAN_DURATION_MINUTES={'NA' if median is None else median}")
    print(f"P80_DURATION_MINUTES={'NA' if p80 is None else p80}")

    recent = sorted(matched, key=lambda item: str(item['endedAt']), reverse=True)[:recent_limit]
    for item in recent:
        print(f"RECENT_RUN={item['headBranch']}|{item['workflowName']}|{item['durationMinutes']}|{item['url']}")

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
