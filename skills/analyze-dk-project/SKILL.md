---
name: analyze-dk-project
description: Determines whether a repository is a dk project via root dk.u and, if so, analyzes its dependencies, modules, slots, and descriptions.
---

## Step 1: Analyze the Project

### Step 1.1 — Attempt direct workspace reads

Try to read the following files and directories directly from the workspace:

1. `dk.u` in the repository root — to determine whether the repository is a dk project
2. `dk.u` in the repository root — to identify dependencies from `%% import` commands
3. All `etc/dk/d/*.json` files — to determine whether the dk package is finished or unfinished for release purposes
4. All `dist-*.u/run.u` files — to extract modules and their slots from dk value shell commands
5. All `etc/dk/v/*.values.{jsonc,lua}` files — to find descriptions for modules
6. Any other project metadata files that might contain dependency or module information

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
- Whether `dk.u` exists in the repository root
- Inventory of dependencies from root `dk.u` `%% import` commands
- Inventory of `etc/dk/d/*.json` files and their contents
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

- [ ] Verified dk-project classification from root `dk.u`
- [ ] If `dk.u` exists, then all of:
      - List of dependencies (from root `dk.u` `%% import` commands)
      - Complete inventory of `etc/dk/d/*.json` files
      - Whether the repository is a finished dk package or an unfinished dk package for release purposes:
        - missing `etc/dk/d/*.json` means unfinished
        - present but no parseable top-level `id` versions means unfinished
        - parseable top-level `id` versions means finished, with a derived release `major.minor` prefix
      - List of `dist-*.u` folders and their `run.u` files
      - For each module referenced via value shell commands:
        - The module name and version
        - All available slots (REQUEST_SLOT values)
        - Prose context snippets from `dist-*.u/run.u`
        - Sampled output paths from relevant `*.values.{jsonc,lua}` files (up to 100 paths)
      - Complete inventory of all `*.values.{jsonc,lua}` files

After collecting those values, the skill (LLM) must synthesize a concise module description itself.
Do not require the helper scripts to compute or infer finalized descriptions.

When summarizing the repository, the skill must make the release-state distinction explicit:

- no root `dk.u` → not a dk project
- root `dk.u` with missing or unparseable `etc/dk/d/*.json` → unfinished dk package
- root `dk.u` with parseable `etc/dk/d/*.json` versions → finished dk package

Only when every checkbox above is filled with real, verified data from the
repository may you proceed.

---
