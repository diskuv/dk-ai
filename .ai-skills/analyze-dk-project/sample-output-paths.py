#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import sys
from typing import Any


def strip_jsonc(text: str) -> str:
    out: list[str] = []
    in_string = False
    string_quote = ''
    escaped = False
    in_line_comment = False
    in_block_comment = False
    i = 0

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ''

        if in_line_comment:
            if ch == '\n':
                in_line_comment = False
                out.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == '*' and nxt == '/':
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == '\\':
                escaped = True
            elif ch == string_quote:
                in_string = False
                string_quote = ''
            i += 1
            continue

        if ch == '/' and nxt == '/':
            in_line_comment = True
            i += 2
            continue

        if ch == '/' and nxt == '*':
            in_block_comment = True
            i += 2
            continue

        if ch in ('"', "'"):
            in_string = True
            string_quote = ch
            out.append(ch)
            i += 1
            continue

        out.append(ch)
        i += 1

    return ''.join(out)


def remove_trailing_commas(text: str) -> str:
    previous = None
    current = text
    while current != previous:
        previous = current
        current = current.replace(',}', '}').replace(',]', ']')
        current = current.replace(',\n}', '\n}').replace(',\n]', '\n]')
        current = current.replace(',\r\n}', '\r\n}').replace(',\r\n]', '\r\n]')
    return current


def parse_jsonc(text: str) -> Any:
    import json

    sanitized = remove_trailing_commas(strip_jsonc(text))
    return json.loads(sanitized)


def collect_output_paths(node: Any, results: list[str]) -> None:
    if isinstance(node, list):
        for item in node:
            collect_output_paths(item, results)
        return

    if not isinstance(node, dict):
        return

    paths = node.get('paths')
    if isinstance(paths, list):
        for item in paths:
            if isinstance(item, str):
                results.append(item)

    for value in node.values():
        collect_output_paths(value, results)


def create_seed(seed_text: str) -> int:
    hash_value = 2166136261
    for char in seed_text:
        hash_value ^= ord(char)
        hash_value = (hash_value * 16777619) & 0xFFFFFFFF
    return hash_value


def next_lcg(state: int) -> int:
    return (state * 1664525 + 1013904223) & 0xFFFFFFFF


def sample_deterministically(items: list[str], limit: int, seed_text: str) -> list[str]:
    ordered = sorted(set(items))
    if len(ordered) <= limit:
        return ordered

    working = list(ordered)
    state = create_seed(seed_text)
    for index in range(len(working) - 1, 0, -1):
        state = next_lcg(state)
        swap_index = int((state / 4294967296) * (index + 1))
        working[index], working[swap_index] = working[swap_index], working[index]
    return sorted(working[:limit])


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print('usage: python sample-output-paths.py VALUES_FILE [MAX_COUNT]', file=sys.stderr)
        return 2

    values_file = pathlib.Path(sys.argv[1]).resolve()
    max_count = int(sys.argv[2]) if len(sys.argv) == 3 else 100
    if max_count <= 0:
        print('MAX_COUNT must be a positive integer', file=sys.stderr)
        return 2

    raw = values_file.read_text(encoding='utf-8')
    parsed = parse_jsonc(raw)
    all_paths: list[str] = []

    forms = parsed.get('forms') if isinstance(parsed, dict) else None
    if isinstance(forms, list):
        for form in forms:
            if isinstance(form, dict) and 'outputs' in form:
                collect_output_paths(form['outputs'], all_paths)

    sample = sample_deterministically(all_paths, max_count, str(values_file))
    print(f'TOTAL_PATHS={len(set(all_paths))}')
    for item in sample:
        print(item)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
