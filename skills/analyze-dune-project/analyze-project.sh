#!/bin/sh
set -euf

if [ "$#" -ne 1 ]; then
    echo "usage: $0 OUTPUT_FILE" >&2
    exit 2
fi

out_file=$1
out_dir=$(dirname "$out_file")
mkdir -p "$out_dir"

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/analyze-dune-project.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

# Create/empty the analysis file
: > "$out_file"

append_section() {
    # $1 = header, $2 = file to append
    printf '\n=== %s ===\n' "$1" >> "$out_file"
    cat "$2" >> "$out_file"
}

# dune-project (no leading blank line to match original)
printf '=== dune-project ===\n' >> "$out_file"
cat dune-project >> "$out_file"

# All dune files
find . -type f -name dune | LC_ALL=C sort | while IFS= read -r f; do
    rel="${f#./}"
    append_section "$rel" "$f"
done

# 1. Find directories containing .ml files with "let%expect_test"
expect_dirs_file="$temp_dir/expect_dirs.txt"
: > "$expect_dirs_file"
find . -type f -name '*.ml' | while IFS= read -r f; do
    if grep -l 'let%expect_test' "$f" >/dev/null 2>&1; then
        dirname "$f"
    fi
done | LC_ALL=C sort -u > "$expect_dirs_file"

# 2. Recursively collect _all_ .ml files in those directories
# There may be test support files that don't have "let%expect_test",
# but we expect them to co-reside in the same directories as the expect tests.
ml_files_file="$temp_dir/ml_files.txt"
: > "$ml_files_file"
while IFS= read -r d; do
    [ -z "$d" ] && continue
    find "$d" -type f -name '*.ml'
done < "$expect_dirs_file" | LC_ALL=C sort -u > "$ml_files_file"

while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#./}"
    append_section "$rel" "$f"
done < "$ml_files_file"

# get full path to $out_file, and write summary
abs_out_file=$(realpath "$out_file")
echo "Analysis complete. Output written to \`$abs_out_file\`."
echo "Please provide the contents back to the agent before proceeding."
