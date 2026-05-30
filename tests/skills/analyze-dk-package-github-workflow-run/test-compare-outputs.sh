#!/bin/sh
set -eu

node_bin=${NODE:-node}
root=$(mktemp -d "${TMPDIR:-/tmp}/dk-ai-workflow-run-test.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM

checkout=$root/checkout
patch_root=$root/patches
mkdir -p "$checkout/dist-demo.u" "$patch_root"
git init -q "$checkout"

printf '%% import Foo\n' > "$checkout/dk.u"
printf 'line 1\nold line\nline 3\n' > "$checkout/dist-demo.u/run.u"

cat > "$patch_root/demo.patch" <<'EOF'
--- dist-demo.u/run.u
+++ dist-demo.u/run.u.actual
@@ -1,3 +1,3 @@
 line 1
-old line
+new line
 line 3
EOF

helper=$(CDPATH= cd -- "$(dirname -- "$0")/../../../skills/analyze-dk-package-github-workflow-run" && pwd)/apply-workflow-patches.js

printf '%s\n' '=== FIRST RUN ==='
"$node_bin" "$helper" --checkout "$checkout" --patch-root "$patch_root"
printf '%s\n' '=== SECOND RUN ==='
"$node_bin" "$helper" --checkout "$checkout" --patch-root "$patch_root"
printf '%s\n' '=== RESULT ==='
cat "$checkout/dist-demo.u/run.u"
