#!/bin/sh
set -euf

if [ "$#" -ne 1 ]; then
    echo "usage: $0 OUTPUT_FILE" >&2
    exit 2
fi

out_file=$1
out_dir=$(dirname "$out_file")
mkdir -p "$out_dir"

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/analyze-noweb-project.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

: > "$out_file"

append_section() {
    printf '\n=== %s ===\n' "$1" >> "$out_file"
    cat "$2" >> "$out_file"
}

find_project_files() {
    find . \
        \( -path './.git' -o -path './_build' -o -path './node_modules' -o -path './.opam' \
           -o -path './_opam' -o -path './dist' -o -path './.direnv' -o -path './.venv' \
           -o -path './venv' -o -path './target' -o -path './bin' -o -path './obj' \) -prune \
        -o "$@"
}

noweb_files_file="$temp_dir/noweb-files.txt"
find_project_files -type f \( -name '*.nw' -o -name '*.noweb' \) | LC_ALL=C sort > "$noweb_files_file"

printf '=== noweb-files ===\n' >> "$out_file"
if [ ! -s "$noweb_files_file" ]; then
    printf '<none found>\n' >> "$out_file"
else
    sed 's#^\./##' "$noweb_files_file" >> "$out_file"
fi

build_files_file="$temp_dir/build-files.txt"
: > "$build_files_file"
for f in \
    dune-project dune-workspace Makefile makefile GNUmakefile package.json \
    pyproject.toml Cargo.toml go.mod pom.xml build.gradle build.gradle.kts \
    settings.gradle settings.gradle.kts .gitlab-ci.yml
do
    [ -f "$f" ] && printf '%s\n' "$f" >> "$build_files_file"
done
find_project_files -type f \( -name dune -o -name '*.opam' \) | LC_ALL=C sort >> "$build_files_file"
if [ -d .github/workflows ]; then
    find .github/workflows -type f \( -name '*.yml' -o -name '*.yaml' \) | LC_ALL=C sort >> "$build_files_file"
fi
sort -u "$build_files_file" -o "$build_files_file"

printf '\n=== build-files ===\n' >> "$out_file"
if [ ! -s "$build_files_file" ]; then
    printf '<none found>\n' >> "$out_file"
else
    sed 's#^\./##' "$build_files_file" >> "$out_file"
fi

printf '\n=== unified-search ===\n' >> "$out_file"
if ! grep -RInE \
    --exclude-dir=.git --exclude-dir=_build --exclude-dir=node_modules \
    --exclude-dir=.opam --exclude-dir=_opam --exclude-dir=dist \
    --exclude-dir=.direnv --exclude-dir=.venv --exclude-dir=venv \
    --exclude-dir=target --exclude-dir=bin --exclude-dir=obj \
    'U2Markdown|UCramRunner|UDuneImport|\.md\.ml\.u|\.ml\.u|promote|runtest' . >/dev/null 2>&1
then
    printf '<no matches found>\n' >> "$out_file"
else
    grep -RInE \
        --exclude-dir=.git --exclude-dir=_build --exclude-dir=node_modules \
        --exclude-dir=.opam --exclude-dir=_opam --exclude-dir=dist \
        --exclude-dir=.direnv --exclude-dir=.venv --exclude-dir=venv \
        --exclude-dir=target --exclude-dir=bin --exclude-dir=obj \
        'U2Markdown|UCramRunner|UDuneImport|\.md\.ml\.u|\.ml\.u|promote|runtest' . \
        | sed 's#^\./##' >> "$out_file"
fi

while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#./}"
    append_section "$rel" "$f"
done < "$build_files_file"

while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#./}"
    append_section "$rel" "$f"
done < "$noweb_files_file"

abs_out_file=$(realpath "$out_file")
echo "Analysis complete. Output written to \`$abs_out_file\`."
echo "Please provide the contents back to the agent before proceeding."
