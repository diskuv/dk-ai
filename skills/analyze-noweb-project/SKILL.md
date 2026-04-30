---
name: analyze-noweb-project
description: Analyze a noweb project to identify chapter files, cross-file references, chunk languages, and existing build/render/promotion workflow before conversion.
---

## Step 1: Analyze the project directly when possible

### Step 1.1 — Locate the noweb sources

Try to read the workspace directly and collect:

1. All `**/*.nw` files
2. All `**/*.noweb` files
3. Any existing generated docs or unified-script files near those sources, for
   example `**/*.md.ml.u`, `**/*.md`, `**/*.u`, or repo-specific literate-doc
   outputs

Do not ask the user to paste these files if you can read them directly.

### Step 1.2 — Read the project’s build and documentation wiring

Read the files that explain how docs, tests, and generated outputs are wired.
Prefer direct workspace reads of:

1. Common root build files if present, for example:
   - `dune-project`, `dune-workspace`
   - `Makefile`, `makefile`, `GNUmakefile`
   - `package.json`
   - `pyproject.toml`
   - `Cargo.toml`
   - `go.mod`
   - `pom.xml`
   - `build.gradle`, `build.gradle.kts`
   - `.gitlab-ci.yml`
2. Recursive build files if present, for example:
   - `**/dune`
   - `.github/workflows/*.{yml,yaml}`
   - repo-specific doc/build scripts
3. Any files that already mention unified or literate tooling, for example
   matches for:
   - `U2Markdown`
   - `UCramRunner`
   - `UDuneImport`
   - `.md.ml.u`
   - `.ml.u`
   - `promote`
   - `runtest`
   - repo-specific doc-generation commands

### Step 1.3 — Derive the required facts

Before any conversion work, derive and write down:

1. The noweb root directory or directories
2. The complete noweb chapter/file set
3. Which noweb files are likely chapter entrypoints versus support fragments
4. Cross-file references between chapters, including explicit `[[...]]` links and
   any other file-level references you can verify
5. A derived chapter order:
   - topological order when dependencies are present
   - otherwise a documented stable order (for example lexical order)
6. Dominant chunk languages, inferred from chunk names, file extensions,
   shebangs, or surrounding prose
7. The target repo’s existing documentation/build/render/test wiring
8. The target repo’s promotion workflow, if any
9. Whether rendered docs should be produced from checked-in unified sources or
   from generated/normalized unified sources

## Step 2: Fallback when direct reads are not enough

If you cannot read the relevant files directly, or if direct access still
leaves any required fact unknown, run the helper script in this skill directory
from the project root.

### Windows PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File {path_to_analyze_noweb_project_skill}\analyze-project.ps1 -OutFile "$env:TEMP\analyze-noweb-project-analysis.txt"
```

### Unix

```bash
sh {path_to_analyze_noweb_project_skill}/analyze-project.sh "${TMPDIR:-/tmp}/analyze-noweb-project-analysis.txt"
```

The script writes a single analysis file with:

- noweb inventory
- discovered build/config inventory
- unified/literate-tooling search results
- the contents of the discovered noweb files
- the contents of the discovered build/config files

If you had to use the helper script, wait for its output to be available before
continuing.

## Step 3: Hard stop rule

If, after Step 1 and Step 2, you still do not have **all** of the following
concrete values, you MUST stop before any migration work and ask for the helper
script output:

- [ ] Verified noweb file inventory
- [ ] Verified chapter entrypoints or a documented fallback rule for choosing them
- [ ] Verified cross-file references or a documented conclusion that none were found
- [ ] Derived chapter ordering rule
- [ ] Dominant chunk language summary
- [ ] Existing doc/build/render/test wiring
- [ ] Existing promotion workflow, or a verified conclusion that none exists
- [ ] A verified decision about whether rendered docs should depend on checked-in
      unified sources or generated/normalized unified sources

Only when every checkbox is satisfied with real project data may you proceed.

## Notes for downstream agents

- Do not assume the project is OCaml-based.
- Do not assume filenames like `DESIGNNN-*`, `USAGE`, `LEXER`, or `PARSER`.
- Do not assume MlFront tools are present. Reuse them only when they already fit
  the target repo.
- Treat language-specific “pretty” transformations as optional. If a concise
  REPL/show-style representation is unavailable or too large, keep the original
  code block or prose rather than forcing a lossy conversion.
