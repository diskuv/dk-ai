#!/bin/sh

set -euf

if [ "$#" -ne 2 ]; then
    printf 'usage: %s POWERSHELL_OUTPUT SHELL_OUTPUT\n' "$0" >&2
    exit 2
fi

ps_output="$1"
sh_output="$2"

normalize_line() {
    line="$1"
    case "$line" in
        '=== '*)
            body="${line#=== }"
            body="${body%% ===}"
            body="${body#./}"
            body="${body#.\\}"
            body=$(printf '%s' "$body" | tr '\\' '/')
            printf '=== %s ===\n' "$body"
            ;;
        *)
            case "$line" in
                .github/workflows/*:[0-9]*:\ *)
                    printf '\n'
                    ;;
                *)
            printf '%s\n' "$line"
                    ;;
            esac
            ;;
    esac
}

normalize_file() {
    file="$1"
    tr -d '\r' < "$file" | while IFS= read -r line || [ -n "$line" ]; do
        normalize_line "$line"
    done | awk '
        {
            lines[NR] = $0
        }
        END {
            last = NR
            while (last > 0 && lines[last] == "") {
                last--
            }
            for (i = 1; i <= last; i++) {
                if (lines[i] == "") {
                    continue
                }
                print lines[i]
            }
        }
    ' | LC_ALL=C sort -u
}

if [ ! -f "$ps_output" ]; then
    printf 'error: PowerShell output file not found: %s\n' "$ps_output" >&2
    exit 1
fi

if [ ! -f "$sh_output" ]; then
    printf 'error: Shell output file not found: %s\n' "$sh_output" >&2
    exit 1
fi

printf 'Loading PowerShell output: %s\n' "$ps_output"
ps_normalized=$(mktemp)
printf 'Loading shell output: %s\n' "$sh_output"
sh_normalized=$(mktemp)
trap 'rm -f "$ps_normalized" "$sh_normalized"' EXIT HUP INT TERM

normalize_file "$ps_output" > "$ps_normalized"
normalize_file "$sh_output" > "$sh_normalized"

ps_lines=$(wc -l < "$ps_normalized")
sh_lines=$(wc -l < "$sh_normalized")

printf '\n'
printf 'PowerShell output: %d lines\n' "$ps_lines"
printf 'Shell output: %d lines\n' "$sh_lines"

ps_headers=$(grep '^=== .* ===$' "$ps_normalized" || true)
sh_headers=$(grep '^=== .* ===$' "$sh_normalized" || true)

ps_section_count=$(printf '%s\n' "$ps_headers" | grep -c . || true)
sh_section_count=$(printf '%s\n' "$sh_headers" | grep -c . || true)

printf '\n'
printf 'PowerShell sections: %d\n' "$ps_section_count"
printf 'Shell sections: %d\n' "$sh_section_count"

if [ "$ps_section_count" -ne "$sh_section_count" ]; then
    printf 'error: Section count mismatch!\n' >&2
    exit 1
fi

if ! diff -q "$ps_normalized" "$sh_normalized" > /dev/null 2>&1; then
    ps_headers_file=$(mktemp)
    sh_headers_file=$(mktemp)
    trap 'rm -f "$ps_normalized" "$sh_normalized" "$ps_headers_file" "$sh_headers_file"' EXIT HUP INT TERM
    printf '%s\n' "$ps_headers" > "$ps_headers_file"
    printf '%s\n' "$sh_headers" > "$sh_headers_file"
    if ! diff -q "$ps_headers_file" "$sh_headers_file" > /dev/null 2>&1; then
        printf 'error: Section header mismatch detected:\n' >&2
        diff -u "$ps_headers_file" "$sh_headers_file" || true
        exit 1
    fi
fi

printf '✓ Section headers match exactly\n'

if ! diff -q "$ps_normalized" "$sh_normalized" > /dev/null 2>&1; then
    printf '\n'
    printf 'Content differences detected:\n'
    diff -u "$ps_normalized" "$sh_normalized" | head -40 || true
    printf 'error: Content mismatch! Review above for details.\n' >&2
    exit 1
fi

printf '✓ File content matches exactly\n'
printf '\n'
printf '✅ All validations passed!\n'
printf 'PowerShell and shell outputs are equivalent.\n'
