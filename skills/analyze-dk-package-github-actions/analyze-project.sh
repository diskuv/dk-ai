#!/bin/sh
set -euf

if [ "$#" -ne 1 ]; then
    echo "usage: $0 OUTPUT_FILE" >&2
    exit 2
fi

out_file=$1
out_dir=$(dirname "$out_file")
mkdir -p "$out_dir"

: > "$out_file"

append_section() {
    printf '\n=== %s ===\n' "$1" >> "$out_file"
}

append_file_section() {
    printf '\n=== %s ===\n' "$1" >> "$out_file"
    awk '
        {
            lines[NR] = $0
        }
        END {
            last = NR
            while (last > 0 && lines[last] == "") {
                last--
            }
            for (i = 1; i <= last; i++) {
                print lines[i]
            }
        }
    ' "$2" >> "$out_file"
}

append_root_file_if_present() {
    rel="$1"
    if [ -f "$rel" ]; then
        append_file_section "$rel" "$rel"
    fi
}

printf '=== DK PROJECT DETECTION ===\n' >> "$out_file"
if [ -f "dk.u" ]; then
    printf 'IsDkProject: true\n' >> "$out_file"
    printf 'RootDkU: dk.u\n' >> "$out_file"
else
    printf 'IsDkProject: false\n' >> "$out_file"
    printf 'RootDkU: (not found)\n' >> "$out_file"
fi

append_section "ROOT FILES"
root_file_count=0
for rel in dk.u dk0 dk0.cmd AGENTS.md; do
    if [ -f "$rel" ]; then
        root_file_count=$((root_file_count + 1))
        append_root_file_if_present "$rel"
    fi
done
if [ "$root_file_count" -eq 0 ]; then
    printf '(not found)\n' >> "$out_file"
fi

append_section "GITHUB ACTIONS WORKFLOWS"
workflow_list=$(mktemp "${TMPDIR:-/tmp}/analyze-dk-package-github-actions.workflows.XXXXXX")
dist_json_list=$(mktemp "${TMPDIR:-/tmp}/analyze-dk-package-github-actions.distjson.XXXXXX")
dist_run_list=$(mktemp "${TMPDIR:-/tmp}/analyze-dk-package-github-actions.distrun.XXXXXX")
highlights_file=$(mktemp "${TMPDIR:-/tmp}/analyze-dk-package-github-actions.highlights.XXXXXX")
trap 'rm -f "$workflow_list" "$dist_json_list" "$dist_run_list" "$highlights_file"' EXIT HUP INT TERM

if [ -d ".github/workflows" ]; then
    find ".github/workflows" -type f \( -name "*.yml" -o -name "*.yaml" \) | LC_ALL=C sort | sed 's#^\./##' > "$workflow_list"
fi
if [ -s "$workflow_list" ]; then
    cat "$workflow_list" >> "$out_file"
    while IFS= read -r rel; do
        append_file_section "$rel" "$rel"
    done < "$workflow_list"
else
    printf '(not found)\n' >> "$out_file"
fi

append_section "DIST VERSION FILES (etc/dk/d/*.json)"
if [ -d "etc/dk/d" ]; then
    find "etc/dk/d" -type f -name "*.json" | LC_ALL=C sort | sed 's#^\./##' > "$dist_json_list"
fi
if [ -s "$dist_json_list" ]; then
    cat "$dist_json_list" >> "$out_file"
    while IFS= read -r rel; do
        append_file_section "$rel" "$rel"
    done < "$dist_json_list"
else
    printf '(not found)\n' >> "$out_file"
fi

append_section "DIST-*.U/RUN.U FILES"
find . -type f -path "*/dist-*.u/run.u" | LC_ALL=C sort | sed 's#^\./##' > "$dist_run_list"
if [ -s "$dist_run_list" ]; then
    cat "$dist_run_list" >> "$out_file"
    while IFS= read -r rel; do
        append_file_section "$rel" "$rel"
    done < "$dist_run_list"
else
    printf '(not found)\n' >> "$out_file"
fi

append_section "GITHUB ACTIONS HIGHLIGHTS"
if [ -s "$workflow_list" ]; then
    while IFS= read -r rel; do
        grep -En '^[[:space:]]*push:[[:space:]]*$|^[[:space:]]*tags:[[:space:]]*$|workflow_dispatch|experimental-mlfront-ref|diskuv/dk-distribute|actions/download-artifact|actions/upload-artifact|softprops/action-gh-release|(^|[^A-Za-z])combine([^A-Za-z]|$)|(^|[^A-Za-z])distribute([^A-Za-z]|$)|gh run (list|view|watch|download)|gh api' "$rel" | sed -E "s#^([0-9]+):(.*)#${rel}:\\1: \\2#" | sed -E 's#(: )[[:space:]]+#\1#' >> "$highlights_file" || true
    done < "$workflow_list"
    sort -u "$highlights_file" -o "$highlights_file"
fi
if [ -s "$highlights_file" ]; then
    cat "$highlights_file" >> "$out_file"
    printf '\n' >> "$out_file"
else
    printf '(no matching workflow lines found)\n' >> "$out_file"
fi

printf 'Analysis complete. Output written to %s\n' "$out_file" >&2
printf 'Please provide the contents back to the agent before proceeding.\n' >&2
