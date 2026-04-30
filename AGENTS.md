# Agents and Skills Standards

This document defines standards for creating and maintaining custom agents and skills in the dk-ai project.

## Overview

- **Agents**: Custom agents are specialized subagents that perform complex, multi-step tasks autonomously
- **Skills**: Reusable, tool-independent procedures that agents and users can invoke
- Both should follow this project's conventions to ensure consistency and maintainability

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
- Dependencies from etc/dk/i
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

### analyze-dk-project (New)

- **Purpose**: Analyze dk package projects
- **Dependencies**: From `etc/dk/i` import directory
- **Modules**: From `dist-*.u/run.u` unified scripts
- **Commands**: All value shell command types
- **Descriptions**: From prose or `*.values.{jsonc,lua}`
- **Patterns**: Multi-command detection, slot extraction

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
