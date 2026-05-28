# Agents and Skills Standards

This document defines standards for creating and maintaining custom agents and skills in the dk-ai project.

## Overview

- **Agents**: Custom agents are specialized subagents that perform complex, multi-step tasks autonomously
- **Skills**: Reusable, tool-independent procedures that agents and users can invoke
- Both should follow this project's conventions to ensure consistency and maintainability

## Available repository skills and agents

This section is intentionally startup-visible. Keep it current so a fresh session
can recognize the repository's checked-in skills and agents without first
searching the tree.

Self-update rule:

1. Whenever any repository skill or agent is added, removed, renamed, or updated,
   update this section in the same change.
2. Keep the name, path, use-when summary, and required gate / hard-stop summary
   accurate for every listed item.
3. Do not defer this inventory update to a later cleanup commit.

### Agents

| Name | Path | Use when | Required gate / hard stop |
| --- | --- | --- | --- |
| `convert-expect-to-unified` | `agents/convert-expect-to-unified.agent.md` | Converting OCaml `ppx_expect` tests into `EXAMPLES.md.ml.u`, rendered docs, and dune wiring. | Must run `analyze-dune-project` first. Stop if package, library, expect-test, or helper-signature facts are missing. |
| `convert-noweb-to-unified` | `agents/convert-noweb-to-unified.agent.md` | Converting noweb documentation into unified-script sources and rendered docs. | Must run `analyze-noweb-project` first. Stop if file inventory, chapter order, cross-file references, build wiring, or promotion facts are missing. |
| `release-dk-project-graph` | `agents/release-dk-project-graph.agent.md` | Releasing a GitHub owner's dk repositories in dependency order. | Must run `analyze-dk-project` for each candidate repo and verify `gh` first. Stop on missing owner, missing dependency/version facts, ambiguous mapping, cycles, dirty temp clones, or unobservable CI. |
| `repair-dk-package-github-actions` | `agents/repair-dk-package-github-actions.agent.md` | Diagnosing or repairing a GitHub Actions-based dk package workflow. | Must run `analyze-dk-package-github-actions` first. Stop if workflow, dk-project, release-prefix, or producer-shaping facts are missing. |

### Skills

| Name | Path | Use when | Required gate / hard stop |
| --- | --- | --- | --- |
| `analyze-dk-package-github-actions` | `skills/analyze-dk-package-github-actions/SKILL.md` | Analyzing a dk package repo's workflows, release-prefix derivation, and `gh` validation path. | Stop if root `dk.u`, workflow inventory, `etc/dk/d/*.json`, `dist-*.u/run.u`, trigger mode, or producer-shaping facts cannot be verified. |
| `analyze-dk-project` | `skills/analyze-dk-project/SKILL.md` | Classifying a repo as a dk project and extracting dependencies, modules, slots, and descriptions. | Stop if root `dk.u`, imports, `dist-*.u/run.u`, module/slot inventory, prose snippets, or values-file inventory cannot be verified. |
| `analyze-dune-project` | `skills/analyze-dune-project/SKILL.md` | Analyzing an OCaml dune project before expect-test conversion. | Stop if `dune-project`, library inventory, expect-test file list, or helper-signature facts are missing. |
| `analyze-noweb-project` | `skills/analyze-noweb-project/SKILL.md` | Analyzing a noweb project's chapters, references, and doc/build wiring before conversion. | Stop if noweb inventory, chapter entrypoints/order, cross-file references, dominant language summary, build wiring, or promotion model are missing. |
| `make-dk-package-from-autoconf` | `skills/make-dk-package-from-autoconf/SKILL.md` | Creating or extending a dk package for an autoconf-based upstream project, including Windows cross-compilation. | Stop if dk-project classification, `dist-*.u/run.u`, primary package and `.Bundle` modules, autoconf references, toolchain references, or dependent package facts are missing. |
| `port-legacy-dk-package-repo` | `skills/port-legacy-dk-package-repo/SKILL.md` | Porting a legacy dk package tree into a standalone package repository. | Treat local validation as only the first pass; unless the user opts out, finish with tag-driven CI. Stop and report concrete blockers instead of guessing layout or pushing a tag just to see failure. |
| `simplify-duplicates` | `skills/simplify-duplicates/SKILL.md` | Analyzing a bounded file set for exact and near-duplicate code. | Stop if the exact file set, success commands, or enough code context to enumerate duplicate clusters are missing. |

## File Structure

### Agents

Located in `agents/` directory with the naming pattern:

```
agents/AGENT_NAME.agent.md
```

**Contents:**
- Frontmatter with YAML (name, description, etc.)
- High-level description of what the agent does
- Step-by-step workflow sections
- Examples of invocation
- Error handling and recovery procedures

### Skills

Located in `skills/SKILL_NAME/` directory containing:

```
skills/SKILL_NAME/
  ├── SKILL.md                  # Main skill documentation
  ├── analyze-project.ps1       # PowerShell implementation (if applicable)
  ├── analyze-project.sh        # Shell/Unix implementation (if applicable)
   ├── [helper-script.js]        # Preferred checked-in structured-data helper
   ├── [helper-script.py]        # Fallback helper when JavaScript is unavailable
   ├── [other-script.lua|etc]    # Additional implementations as needed
  └── [README.md]               # Optional supplementary documentation
```

### Tests

Located in `tests/` mirroring source structure:

```
tests/
  ├── agents/
  │   └── AGENT_NAME/
  │       ├── README.md
  │       └── [smoke.prompt.md]
  └── skills/
      └── SKILL_NAME/
          ├── README.md
          ├── test-compare-outputs.ps1
          └── test-compare-outputs.sh
```

## SKILL.md Format

The `SKILL.md` file should follow this structure:

```markdown
---
name: skill-name
description: One-line description of what the skill does
---

## Step 1: Attempt Direct Reads

### Step 1.1 — Attempt direct workspace reads

Try to read:
- Specific files/directories
- Do not ask user to paste content

### Step 1.2 — Fallback: Run helper scripts

If direct reads fail, run the helper script:

**Windows PowerShell:**
```powershell
powershell -ExecutionPolicy Bypass -File {path}\analyze-project.ps1 -OutFile "$env:TEMP\output.txt"
```

**Unix/Linux:**
```bash
sh {path}/analyze-project.sh "${TMPDIR:-/tmp}/output.txt"
```

### Step 1.3 — Hard stop rule

If after Step 1 and 1.2 you do **not** have all required values, 
you **MUST** stop and ask the user to run the script and paste its output.

Required values before continuing:
- [ ] Concrete value 1
- [ ] Concrete value 2
- [ ] Concrete value 3

Only when **every checkbox** is filled with real, verified data may you proceed.

---
```

## Naming Conventions

### Agents

Use kebab-case:
- `convert-expect-to-unified`
- `modernize-dotnet-app`
- `analyze-legacy-system`

### Skills

Use kebab-case:
- `analyze-dune-project`
- `analyze-noweb-project`
- `analyze-dk-project`

Pattern: `analyze-*-project` or `migrate-*` or `convert-*` or descriptive action

### Scripts Within Skills

Use descriptive names matching the pattern of the skill:
- `analyze-project.ps1` (PowerShell)
- `analyze-project.sh` (Shell/Unix)
- `sample-output-paths.js` or similar for structured-data extraction
- `sample-output-paths.py` or similar as the non-JavaScript fallback
- Additional implementations as needed for specific languages

## Cross-Platform Support

### Multi-Language Scripts

Skills should provide implementations for multiple platforms:

1. **Windows (PowerShell)**
   - File: `analyze-project.ps1`
   - Must handle UTF-8 encoding explicitly
   - Use `$ErrorActionPreference = 'Stop'` for fail-fast behavior
   - Create temp files in `$env:TEMP`

2. **Unix/Linux/macOS (Shell)**
   - File: `analyze-project.sh`
   - Use POSIX shell syntax (`sh`, not `bash` extensions)
   - Use `set -euf` for safety
   - Use `"${TMPDIR:-/tmp}"` for temp directories
   - Must be executable (`chmod +x`)
   - On Windows, prefer Git Bash for running and testing shell scripts; do not default to WSL bash unless Git Bash is unavailable

3. **Output Consistency**
   - Both scripts must produce structurally identical output
   - Use UTF-8 without BOM
   - Use forward slashes (`/`) for paths even on Windows
   - Normalize line endings to LF

### Testing Cross-Platform Equivalence

Tests must verify:
- ✓ Both PowerShell and shell outputs contain identical required sections
- ✓ Both scripts extract the same data (allowing for formatting differences)
- ✓ Output is valid UTF-8
- ✓ Paths are normalized consistently

When running shell-script tests on Windows:
- Use Git Bash (`C:/Program Files/Git/bin/bash.exe` or equivalent Git installation path) in preference to WSL bash
- Only fall back to WSL bash if Git Bash is not installed
- Record which bash runtime was used when reporting results if the distinction matters

**Test files:**
- `test-compare-outputs.ps1` (Windows PowerShell comparison)
- `test-compare-outputs.sh` (Unix shell comparison)

## Documentation Standards

### README Files

`tests/CATEGORY/SKILL_OR_AGENT_NAME/README.md` should include:

1. **Overview** - What is being tested and why
2. **Quick Start** - Steps to run tests immediately
3. **Detailed Test Procedure** - Step-by-step walkthrough
4. **Expected Patterns** - What output should look like
5. **Troubleshooting** - Common issues and solutions
6. **Integration** - How this fits into the larger system
7. **Test Coverage** - Checklist of what should be tested

### Code Comments

- Explain the "why", not the "what"
- Functions should have brief descriptions
- Complex logic should be broken into named sections

## Skill Implementation Guidelines

### Analysis Scripts

When implementing analysis scripts that inspect project structure:

1. **Read Attempt (Direct)**
   - Try filesystem operations first
   - No prompting or manual intervention
   - Fail gracefully if files not found

2. **Fallback (Script)**
   - Create helper scripts as backup
   - For structured data extraction, prefer checked-in JavaScript helpers first and checked-in Python helpers second
   - Do not rely on `jq` for primary project logic; use repository scripts so behavior is testable and portable
   - Scripts should output to a temp file
   - Output format must be well-defined

3. **Validation**
   - Verify all required data was extracted
   - Do not proceed if critical data is missing
   - Provide clear error messages

### Output Format

Analysis outputs should:
- Use clear section headers (e.g., `=== SECTION NAME ===`)
- Include file contents in readable blocks
- Be sorted consistently for reproducibility
- Handle encoding explicitly (UTF-8)
- Normalize paths for cross-platform consistency

## Versioning

- Skills and agents do not use individual version numbers
- All changes are tracked via git commit history
- Breaking changes to skill interfaces should be clearly documented

## Error Handling

### Hard Stops

Skills should implement "hard stop" rules when critical data cannot be obtained:

```markdown
### Step 1.3 — Hard stop rule

If, after Step 1.1 and Step 1.2, you still do not have **all** of the
following concrete values, you **MUST** stop and ask the user to run
`analyze-project.ps1` or `analyze-project.sh` and paste its output.

Required values before continuing:

- [ ] Value 1 from source
- [ ] Value 2 from source
- [ ] Value 3 from source
```

### Agent Error Recovery

Agents should:
- Report specific, actionable error messages
- Provide recovery steps
- Log progress to memory when appropriate
- Use retry logic for transient failures

## Memory Management

### Session Memory

Use `memory` tool for task-specific context:
- Path: `/memories/session/plan.md`
- Contains: Current task plan, progress notes
- Cleared after session ends

### Repository Memory

Use `memory` tool for codebase facts:
- Path: `/memories/repo/notes.md`
- Contains: Build commands, project structure, verified practices
- Persists within workspace

Example:
```
# analyze-dk-project Skill

## Created: April 2026

Identifies:
- Dependencies from root dk.u %% import commands
- Modules in dist-*.u folders
- Module slots from run.u scripts
- Descriptions from *.values.{jsonc,lua}

## Key Files
- skills/analyze-dk-project/SKILL.md
- skills/analyze-dk-project/analyze-project.ps1
- skills/analyze-dk-project/analyze-project.sh
```

## Quality Checklist

Before committing a new skill or agent:

- [ ] SKILL.md or agent file follows this project's format
- [ ] Helper scripts (if needed) work on Windows and Unix
- [ ] Helper scripts output to temp directories
- [ ] Test files exist (README.md + comparison scripts)
- [ ] Cross-platform output is equivalent
- [ ] All required sections documented in SKILL.md
- [ ] Hard-stop rule is clear and actionable
- [ ] Code includes explanatory comments
- [ ] Encoding is UTF-8 throughout
- [ ] Path handling is consistent (forward slashes)

## Examples in This Repository

### analyze-dune-project

- **Purpose**: Analyze OCaml Dune projects
- **Languages**: OCaml (Dune build system)
- **Analysis**: Library names, expect-test locations
- **Patterns**: SKILL.md with fallback script pattern

### analyze-noweb-project

- **Purpose**: Analyze literate noweb projects
- **Languages**: Noweb with markdown/literate code
- **Analysis**: Chapter structure, cross-references
- **Patterns**: SKILL.md with fallback script pattern

### analyze-dk-project

- **Purpose**: Analyze dk package projects
- **Dependencies**: From root `dk.u` `%% import` commands
- **Modules**: From `dist-*.u/run.u` unified scripts
- **Commands**: All value shell command types
- **Descriptions**: From prose or `*.values.{jsonc,lua}`
- **Patterns**: Multi-command detection, slot extraction

### make-dk-package-from-autoconf

- **Purpose**: Create or extend dk packages for autoconf-based upstream projects, including Windows LLVM-MinGW cross-compilation guidance
- **Recipe references**: Use `CommonsBase_GNU` for the full autoconf/toolchain recipe patterns (`Make.Autoconf`, `Make.Win32.LLVM_MinGW`, W64dev, MinGW)
- **Layout references**: Use `CommonsBase_FileMagic` for a simpler standalone package-repo layout (`dk.u`, `dist-any.u`, workflow, distribution metadata)
- **Layout choice**: Prefer the FileMagic layout for compact single-package repos with one honest `dist-any.u`; prefer the GNU layout for larger multi-package or split-distribution repos
- **Validation rule**: Treat local validation as a first pass only; for dk packages, finish with tag-driven CI validation unless the user explicitly says not to

---

## Questions and Guidelines

**Q: When should I create a skill vs. having the agent do it directly?**
A: Create a skill when the functionality:

- Is reusable by multiple agents
- Can be tested independently
- Benefits from cross-platform implementations
- Has clear input/output contracts

**Q: What if my analysis needs to call external tools?**
A: Use helper scripts that:

- Run from the project root
- Output to temp directories
- Handle missing tools gracefully
- Provide clear error messages

**Q: How do I handle binary or non-UTF8 files?**
A: Document your assumptions in SKILL.md and helper script headers.
If needed, implement encoding conversions explicitly (e.g., `dos2unix`).

---

**Last Updated**: April 2026
**Maintained By**: dk-ai project team
