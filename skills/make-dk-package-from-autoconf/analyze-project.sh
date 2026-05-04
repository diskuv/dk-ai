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
    # $1 = header, $2 = file
    printf '\n=== %s ===\n' "$1" >> "$out_file"
    cat "$2" >> "$out_file"
}

is_relevant_values_file() {
    # $1 = file path
    file=$1
    name=$(basename "$file")
    case "$name" in
        *.Bundle.values.jsonc|*Autoconf*.values.jsonc|*Win32.LLVM_MinGW*.values.jsonc|Toolchain.W64dev*.values.jsonc|Toolchain.MinGW*.values.jsonc)
            return 0
            ;;
    esac

    if grep -Eq '\./configure|Toolchain\.W64dev|Toolchain\.MinGW|mingw-host-triplet' "$file"; then
        return 0
    fi
    return 1
}

printf '=== DK PROJECT DETECTION ===\n' >> "$out_file"
if [ -f dk.u ]; then
    printf 'IsDkProject: true\n' >> "$out_file"
    printf 'RootDkU: dk.u\n' >> "$out_file"
    append_section "dk.u" "dk.u"
else
    printf 'IsDkProject: false\n' >> "$out_file"
    printf 'RootDkU: (not found)\n' >> "$out_file"
fi

printf '\n=== DIST-*.U/RUN.U FILES ===\n' >> "$out_file"
dist_list=$(find . -type f -path './dist-*.u/run.u' | LC_ALL=C sort || true)
if [ -z "$dist_list" ]; then
    printf '(not found)\n' >> "$out_file"
else
    printf '%s\n' "$dist_list" | sed 's#^\./##' >> "$out_file"
    printf '%s\n' "$dist_list" | while IFS= read -r file; do
        [ -z "$file" ] && continue
        append_section "${file#./}" "$file"
    done
fi

printf '\n=== AUTOCONF-RELATED VALUES FILES ===\n' >> "$out_file"
values_tmp=$(mktemp "${TMPDIR:-/tmp}/make-dk-package-from-autoconf-values.XXXXXX")
trap 'rm -f "$values_tmp"' EXIT HUP INT TERM
: > "$values_tmp"

if [ -d etc/dk/v ]; then
    find etc/dk/v -type f -name '*.values.jsonc' | LC_ALL=C sort | while IFS= read -r file; do
        if is_relevant_values_file "$file"; then
            printf '%s\n' "$file" >> "$values_tmp"
        fi
    done
fi

if [ ! -s "$values_tmp" ]; then
    printf '(not found)\n' >> "$out_file"
else
    cat "$values_tmp" >> "$out_file"
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        append_section "$file" "$file"
    done < "$values_tmp"
fi

abs_out_file=$(realpath "$out_file")
echo "Analysis complete. Output written to \`$abs_out_file\`."
echo "Please provide the contents back to the agent before proceeding."
