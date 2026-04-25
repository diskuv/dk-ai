---
name: analyze-dune-project
description: Analyzes an OCaml project to extract package name, library names, and expect-test locations.
---

## Step 1: Analyze the Project

### Step 1.1 — Attempt direct workspace reads

Try to read the following files directly from the workspace:

1. `dune-project` — to find the package name
2. All `**/dune` files — to find library names (`(library (name ...))` stanzas)
3. All `**/*.ml` files containing `let%expect_test` — to find the expect tests to convert

Do not ask the user to paste these files.

### Step 1.2 — Fallback: run `analyze-project.ps1`

If **any** of the files above cannot be read directly (for example, when the
assistant has no filesystem tool, or the workspace is not mounted), you MUST
stop and run [analyze-project.ps1](analyze-project.ps1) script
in PowerShell on Windows from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File {path_to_analyze_dune_project_skill}\analyze-project.ps1 -OutFile "$env:TEMP\analyze-dune-project-analysis.txt"
```

or on Unix run [analyze-project.sh](analyze-project.sh):

```bash
sh {path_to_analyze_dune_project_skill}/analyze-project.sh "${TMPDIR:-/tmp}/analyze-dune-project-analysis.txt"
```

The script will write the requested output file with the contents of dune-project, dune files, and expect-test .ml files. Any temporary scratch files should be created in the OS temp directory, not in the repository.
Then wait for the output file contents to be provided back before continuing.

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you MUST stop and ask the user to run
`analyze-project.ps1` or `analyze-project.sh` on Unix and paste its output.

Required values before continuing:

- [ ] Package name (from `dune-project`)
- [ ] List of library names and their directories (from `dune` files)
- [ ] List of `.ml` files containing `let%expect_test`
- [ ] For each expect test: the helper function(s) it uses and their
      signatures, so the skill can determine whether they use
      `Format.printf` (convertible) or `Printf.printf` / `print_endline`
      (must be rewritten)

Only when every checkbox above is filled with real, verified data from the
repository may you proceed.

---
