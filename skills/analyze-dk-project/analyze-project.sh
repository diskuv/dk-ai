#!/bin/sh
set -euf

if [ "$#" -ne 1 ]; then
    echo "usage: $0 OUTPUT_FILE" >&2
    exit 2
fi

out_file=$1
out_dir=$(dirname "$out_file")
mkdir -p "$out_dir"
script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/analyze-dk-project.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

# Create/empty the analysis file
: > "$out_file"

append_section() {
    # $1 = header
    printf '\n=== %s ===\n' "$1" >> "$out_file"
}

append_file_section() {
    # $1 = header, $2 = file to append
    printf '\n=== %s ===\n' "$1" >> "$out_file"
    cat "$2" >> "$out_file"
}

resolve_values_sampler() {
    if command -v node >/dev/null 2>&1 && [ -f "$script_dir/sample-output-paths.js" ]; then
        printf 'node\n%s/sample-output-paths.js\n' "$script_dir"
        return 0
    fi

    if command -v python3 >/dev/null 2>&1 && [ -f "$script_dir/sample-output-paths.py" ]; then
        printf 'python3\n%s/sample-output-paths.py\n' "$script_dir"
        return 0
    fi

    if command -v python >/dev/null 2>&1 && [ -f "$script_dir/sample-output-paths.py" ]; then
        printf 'python\n%s/sample-output-paths.py\n' "$script_dir"
        return 0
    fi

    return 1
}

sampler_info=$(resolve_values_sampler || true)
sampler_command=$(printf '%s' "$sampler_info" | sed -n '1p')
sampler_script=$(printf '%s' "$sampler_info" | sed -n '2p')

# 1. Scan etc/dk/i for dependencies
printf '=== DEPENDENCIES (from etc/dk/i) ===\n' >> "$out_file"
if [ -d "etc/dk/i" ]; then
    find "etc/dk/i" -type f -o -type d | LC_ALL=C sort | sed 's|^\./||' >> "$out_file"
else
    printf '(etc/dk/i directory not found)\n' >> "$out_file"
fi

# 2. Find and scan all dist-*.u/run.u files
append_section "DIST-*.U/RUN.U FILES"
find . -type f -name "run.u" -path "*/dist-*.u/run.u" | LC_ALL=C sort > "$temp_dir/dist-run-files.txt"
if [ -s "$temp_dir/dist-run-files.txt" ]; then
while IFS= read -r f; do
    rel="${f#./}"
    append_file_section "$rel" "$f"
done < "$temp_dir/dist-run-files.txt"
else
    printf '(no dist-*.u/run.u files found)\n' >> "$out_file"
fi

# 3. Find and scan all etc/dk/v/*.values.{jsonc,lua} files
# Extract filenames from JSON outputs (sample up to 100)
append_section "VALUES FILES (etc/dk/v/*.values.*)"
if [ -d "etc/dk/v" ]; then
    find "etc/dk/v" -type f \( -name "*.values.jsonc" -o -name "*.values.lua" \) | LC_ALL=C sort > "$temp_dir/values-files.txt"
    if [ -s "$temp_dir/values-files.txt" ]; then
    while IFS= read -r f; do
        rel="${f#./}"
        printf '\n=== %s ===\n' "$rel" >> "$out_file"
        
        if [ -n "$sampler_command" ] && [ -n "$sampler_script" ]; then
            if "$sampler_command" "$sampler_script" "$f" 100 > "$temp_dir/sampled-paths.txt" 2> "$temp_dir/sampled-paths.err"; then
                total_line=$(sed -n '1p' "$temp_dir/sampled-paths.txt")
                outputs_count=$(printf '%s' "$total_line" | sed -n 's/^TOTAL_PATHS=//p')
                if [ -n "$outputs_count" ] && [ "$outputs_count" -gt 0 ]; then
                    printf 'Sample outputs (max 100 of %s total):\n' "$outputs_count" >> "$out_file"
                    sed '1d' "$temp_dir/sampled-paths.txt" >> "$out_file"
                elif [ "$outputs_count" = "0" ]; then
                    printf '(no outputs found in forms array)\n' >> "$out_file"
                else
                    err_text=$(tr '\n' ' ' < "$temp_dir/sampled-paths.err")
                    printf '(error parsing JSON: unexpected sampler output%s%s)\n' "${err_text:+ - }" "$err_text" >> "$out_file"
                fi
            else
                err_text=$(tr '\n' ' ' < "$temp_dir/sampled-paths.err")
                printf '(error parsing JSON%s%s)\n' "${err_text:+: }" "$err_text" >> "$out_file"
            fi
        else
            printf '(error parsing JSON: neither Node.js nor Python is available for sampling values file outputs)\n' >> "$out_file"
        fi
    done < "$temp_dir/values-files.txt"
    else
        printf '(no *.values.jsonc or *.values.lua files found)\n' >> "$out_file"
    fi
else
    printf '(etc/dk/v directory not found)\n' >> "$out_file"
fi

# 4. Extract and summarize MODULE@VERSION references from run.u files
append_section "MODULE@VERSION EXTRACTION SUMMARY"

# Create a combined file of all run.u content for analysis
all_run_u="$temp_dir/all_run_u.txt"
: > "$all_run_u"
while IFS= read -r f; do
    cat "$f" >> "$all_run_u"
    printf '\n' >> "$all_run_u"
done < "$temp_dir/dist-run-files.txt"

if [ -s "$all_run_u" ]; then
    # Extract MODULE@VERSION and related info using grep and sed
    # Pattern 1: Commands with -s/--slot option (get-object, install-object, enter-object)
    grep -oE '(get-object|install-object|enter-object)\s+[A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+\s+(-s|--slot)\s+[A-Za-z0-9_.-]+' "$all_run_u" 2>/dev/null | \
    sed -E 's/(get-object|install-object|enter-object)\s+([A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+)\s+(-s|--slot)\s+([A-Za-z0-9_.-]+)/\1|\2|\4/' | \
    sort -u | while IFS='|' read -r cmd module slot; do
        echo ""
        echo "Module: $module"
        echo "Commands: $cmd"
        echo "Slots: $slot"
        prose_context=$(awk -v module="$module" '
            { lines[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] ~ /(get-object|install-object|enter-object|get-asset|get-bundle|post-object)[[:space:]]+/ && index(lines[i], module) > 0) {
                        start = i - 8; if (start < 1) start = 1;
                        out = "";
                        for (j = start; j < i; j++) {
                            line = lines[j];
                            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
                            if (line == "" || line ~ /^#/ || line ~ /^\$/ || line ~ /^\\/ || line ~ /^---/ || line ~ /^```/ || line ~ /^[{}"]/ ) continue;
                            if (out != "") out = out " | ";
                            out = out line;
                        }
                        print out;
                        exit;
                    }
                }
            }
        ' "$all_run_u")
        if [ -n "$prose_context" ]; then
            echo "ProseContext: $prose_context"
        fi
    done >> "$out_file"
    
    # Pattern 2: Commands without slot (get-asset, get-bundle, post-object)
    grep -oE '(get-asset|get-bundle|post-object)\s+[A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+' "$all_run_u" 2>/dev/null | \
    sed -E 's/(get-asset|get-bundle|post-object)\s+([A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+)/\1|\2/' | \
    sort -u | while IFS='|' read -r cmd module; do
        echo ""
        echo "Module: $module"
        echo "Commands: $cmd"
        prose_context=$(awk -v module="$module" '
            { lines[NR] = $0 }
            END {
                for (i = 1; i <= NR; i++) {
                    if (lines[i] ~ /(get-object|install-object|enter-object|get-asset|get-bundle|post-object)[[:space:]]+/ && index(lines[i], module) > 0) {
                        start = i - 8; if (start < 1) start = 1;
                        out = "";
                        for (j = start; j < i; j++) {
                            line = lines[j];
                            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
                            if (line == "" || line ~ /^#/ || line ~ /^\$/ || line ~ /^\\/ || line ~ /^---/ || line ~ /^```/ || line ~ /^[{}"]/ ) continue;
                            if (out != "") out = out " | ";
                            out = out line;
                        }
                        print out;
                        exit;
                    }
                }
            }
        ' "$all_run_u")
        if [ -n "$prose_context" ]; then
            echo "ProseContext: $prose_context"
        fi
    done >> "$out_file"
fi

printf '\nAnalysis complete. Output written to %s\n' "$out_file" >&2
printf 'Please provide the contents back to the agent before proceeding.\n' >&2
