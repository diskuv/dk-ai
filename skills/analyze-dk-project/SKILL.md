---
name: analyze-dk-project
description: Analyzes a dk project to identify dependencies, modules, slots, and descriptions from dist-*.u folders and related metadata files.
---

## Step 1: Analyze the Project

### Step 1.1 — Attempt direct workspace reads

Try to read the following files and directories directly from the workspace:

1. `etc/dk/i` — to identify imported dependencies
2. All `dist-*.u/run.u` files — to extract modules and their slots from dk value shell commands
3. All `etc/dk/v/*.values.{jsonc,lua}` files — to find descriptions for modules
4. Any other project metadata files that might contain dependency or module information

Do not ask the user to paste these files.

### Step 1.2 — Fallback: run `analyze-project.ps1`

If **any** of the critical files or directories above cannot be read directly (for example, when the
assistant has no filesystem tool, or the workspace is not mounted), you MUST
stop and run [analyze-project.ps1](analyze-project.ps1) script
in PowerShell on Windows from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File {path_to_analyze_dk_project_skill}\analyze-project.ps1 -OutFile "$env:TEMP\analyze-dk-project-analysis.txt"
```

or on Unix run [analyze-project.sh](analyze-project.sh):

```bash
sh {path_to_analyze_dk_project_skill}/analyze-project.sh "${TMPDIR:-/tmp}/analyze-dk-project-analysis.txt"
```

The script will write the requested output file with:
- Inventory of dependencies from `etc/dk/i`
- All `dist-*.u/run.u` files
- Sampled output paths (up to 100 per values file) from `etc/dk/v/*.values.{jsonc,lua}`
- Summary of extracted modules, slots, commands, and prose context snippets

Any temporary scratch files should be created in the OS temp directory, not in the repository.
Then wait for the output file contents to be provided back before continuing.

### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you MUST stop and ask the user to run
`analyze-project.ps1` or `analyze-project.sh` on Unix and paste its output.

Required values before continuing:

- [ ] List of dependencies (from `etc/dk/i`)
- [ ] List of `dist-*.u` folders and their `run.u` files
- [ ] For each module referenced via value shell commands:
      - The module name and version
      - All available slots (REQUEST_SLOT values)
      - Prose context snippets from `dist-*.u/run.u`
      - Sampled output paths from relevant `*.values.{jsonc,lua}` files (up to 100 paths)
- [ ] Complete inventory of all `*.values.{jsonc,lua}` files

After collecting those values, the skill (LLM) must synthesize a concise module description itself.
Do not require the helper scripts to compute or infer finalized descriptions.

Only when every checkbox above is filled with real, verified data from the
repository may you proceed.

---
