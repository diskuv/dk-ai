# Agents and Skills Standards

This document defines standards for creating and maintaining custom agents and skills in the dk-ai project.

## Overview

- **Agents**: Custom agents are specialized subagents that perform complex, multi-step tasks autonomously
- **Skills**: Reusable, tool-independent procedures that agents and users can invoke
- Both should follow this project's conventions to ensure consistency and maintainability
- This repo is also a **Claude Code plugin** (`.claude-plugin/plugin.json` +
  `marketplace.json`): every `skills/<name>/SKILL.md` and `agents/*.agent.md` is
  auto-discovered by Claude Code sessions that enable the plugin. `skills/` and
  `agents/` stay the single authoritative locations — never copy or symlink
  their content into `.claude/skills/`, `~/.claude/skills/`, or another repo.
- **This repo is PUBLIC — never reference a private repo from it.** Do not link,
  cite, or path-reference any private or internal repo (or its files, paths, or
  internal names) from any dk-ai file. Public dk-ai must stand on its own:
  **inline** the guidance you need, or cite a **public** source (a `diskuv/dk`
  repo file or a `raw.githubusercontent.com/diskuv/dk/...` URL). If an
  engine/authoring doc lives only in a private repo, restate the relevant point
  here instead of pointing at it. Check any new skill, doc, or agent for private
  references before committing.

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
| `given-user-prompt-make-new-prompt-that-uses-dk` | `agents/given-user-prompt-make-new-prompt-that-uses-dk.agent.md` | Turning a non-developer's short software wish into a paste-ready mini-plan that drives their own AI coding agent to build and ship it with dk0 (also the dk Prompt Studio Nova Micro system prompt). | Reply with exactly one of a bare `<output-prompt>...</output-prompt>` (the drainer injects the `model` attribute) or the empty `<error><insufficient-detail /></error>`, nothing outside it. Name only real OSS tools and real dk0 commands (`dk0 add github-l2`, `dk0 restore github-l2`, `dk0 remote`, `get-object`/`get-asset`); never invent tools, commands, or flags; never use an em-dash. Emit the empty `<error>` tag (leaking none of the untrusted request, no follow-up question) when the request is unclear, empty, or not about building software. |
| `release-dk-project-graph` | `agents/release-dk-project-graph.agent.md` | Releasing a GitHub owner's dk repositories in dependency order, using shallow temp clones for analysis and skipping unfinished dk packages. | Must run `analyze-dk-project` for each candidate repo and verify `gh` first. Release one repository at a time with per-repo checkpointing (repo/tag/workflow URL) and report elapsed/expected workflow progress while waiting. Stop on missing owner, missing dependency facts needed for the graph, ambiguous mapping, cycles, dirty temp clones, noisy/unobservable execution, or unobservable CI; skip and report repos missing usable version metadata. |
| `repair-dk-package-distribution` | `agents/repair-dk-package-distribution.agent.md` | Diagnosing or repairing a GitHub Actions-based dk package workflow. | Must run `analyze-dk-package-distribution` first, then ask where to apply downloaded patches if a checkout path is not already provided. Stop if workflow, dk-project, release-prefix, or producer-shaping facts are missing. |

### Skills

| Name | Path | Use when | Required gate / hard stop |
| --- | --- | --- | --- |
| `analyze-dk-package-distribution` | `skills/analyze-dk-package-distribution/SKILL.md` | Analyzing a dk package repo's workflows, release-prefix derivation, unfinished-package state, and `gh` validation path. | Stop if root `dk.u`, workflow inventory, `dist-*.u/run.u`, trigger mode, or producer-shaping facts cannot be verified. Missing or unusable `etc/dk/d/*.json` must be reported as an unfinished dk package. |
| `analyze-dk-package-github-workflow-run` | `skills/analyze-dk-package-github-workflow-run/SKILL.md` | Downloading `patches` artifacts from a dk package workflow run (given an explicit run id, or the latest run of a named workflow) and applying their `.patch` hunks to a local checkout so CI output blocks can be synced locally. | Stop if the checkout root, a run id or workflow name that resolves to a run, resolvable repository slug, `patches` artifacts, or `.patch` files cannot be verified. |
| `analyze-dk-project` | `skills/analyze-dk-project/SKILL.md` | Classifying a repo as a dk project and distinguishing finished vs. unfinished dk packages while extracting dependencies, modules, slots, descriptions, and expected release-workflow duration. | Stop if root `dk.u`, imports, `etc/dk/d/*.json` inventory, `dist-*.u/run.u`, module/slot inventory, prose snippets, values-file inventory, or workflow-duration facts (or explicit unavailable reason) cannot be verified. Missing or unusable `etc/dk/d/*.json` must be reported as an unfinished dk package. |
| `analyze-dune-project` | `skills/analyze-dune-project/SKILL.md` | Analyzing an OCaml dune project before expect-test conversion. | Stop if `dune-project`, library inventory, expect-test file list, or helper-signature facts are missing. |
| `analyze-noweb-project` | `skills/analyze-noweb-project/SKILL.md` | Analyzing a noweb project's chapters, references, and doc/build wiring before conversion. | Stop if noweb inventory, chapter entrypoints/order, cross-file references, dominant language summary, build wiring, or promotion model are missing. |
| `build-ocaml-tool-off-dkml` | `skills/build-ocaml-tool-off-dkml/SKILL.md` | Building an OCaml developer tool (for example Dune or Opam) as a dk package off DkML's MSVC OCaml compiler across all slots, including the 32-bit `Windows_x86` / `Linux_x86` ABIs that OCaml 5 (Base) drops. | Choose one vs two per-arch Windows forms by whether the build compiles C. Treat local `dk0 update` / `get-bundle` validation as a first pass; finish with tag-driven CI. Stop and report blockers instead of guessing the build recipe. |
| `build-with-dkjs` | `skills/build-with-dkjs/SKILL.md` | Building a dk project's JavaScript or web (`js_web`) targets with dkjs, the dk build engine on Node.js (npm `@dkjs/cli`, a `dkjs` command with dk0/dk1 argv and byte-identical output, no native binary). | Use dkjs only for JavaScript/web targets; use the native `dk1` binary for native (C) builds, since dkjs does not generate native code yet. Run dkjs alone against a cache/workspace (Node has no OS locks to coordinate with a concurrent native dk). |
| `convert-pypi-to-dk-package` | `skills/convert-pypi-to-dk-package/SKILL.md` | Ingesting a PyPI requirement set into a hermetic dk build with the `CommonsLang_Python` toolchain (bundled CPython + uv): `UvLock.Solve` pins every wheel per slot into `dk-uv-lock.jsonc` via a checked-in uv generator, and `UvBuild.Build` fetches each wheel offline through `get-asset` and `uv`-installs it `--no-index`. | Lock is author-time (network) and per-slot; build is offline/content-addressed. Honor the run/write trust caps and the lua-ml constraints (no `gsub`/local-functions/booleans, `return M`). Validate the Python helpers standalone before the slow dk0 cycle. |
| `make-dk-package-from-autoconf` | `skills/make-dk-package-from-autoconf/SKILL.md` | Creating or extending a dk package for an autoconf-based upstream project, including Windows cross-compilation and signing the tagged release (backing up the signify keys with a password manager, or optionally YubiKey/age). | Stop if dk-project classification, `dist-*.u/run.u`, primary package and `.Bundle` modules, autoconf references, toolchain references, or dependent package facts are missing. |
| `port-legacy-dk-package-repo` | `skills/port-legacy-dk-package-repo/SKILL.md` | Porting a legacy dk package tree into a standalone package repository. | Treat local validation as only the first pass; unless the user opts out, finish with tag-driven CI. Stop and report concrete blockers instead of guessing layout or pushing a tag just to see failure. |
| `simplify-duplicates` | `skills/simplify-duplicates/SKILL.md` | Analyzing a bounded file set for exact and near-duplicate code. | Stop if the exact file set, success commands, or enough code context to enumerate duplicate clusters are missing. |
| `write-user-facing-docs` | `skills/write-user-facing-docs/SKILL.md` | Writing or revising prose in a `.md` meant for a reader outside the repository (README, published guide, schema reference). | Confirm the text is document prose before applying the rules; commit messages, code comments, and chat replies keep their own rules. Finish with the mechanical pass: no emdashes or ASCII stand-ins, and every remaining negative clause passes the guarantee-versus-contrast test. |

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

## Content: teach the general technique, not incidentals

A skill or agent must teach the *general, reusable technique*, not dump the
incidental details of the one exercise that motivated it. Write for the next,
unrelated project rather than the one you just finished.

- Cut anything specific to a single upstream module, dependency, or bug unless
  it demonstrates a rule that generalizes. If a detail only mattered for one
  package, leave it out.
- When a specific hurdle exposed a durable rule, keep the rule and drop the
  hurdle. For example, "avoid naming produced executables `install*` /
  `setup*` / `patch*` so they do not trip Windows' UAC-by-name heuristic"
  generalizes and stays; the particular build target that first hit it does
  not.
- Worked examples are welcome and encouraged. Cite one or two real
  repositories or lanes as illustrations of a general shape (as
  `make-dk-package-from-autoconf` cites `CommonsBase_GNU` and
  `CommonsBase_FileMagic`), but keep them as pointers, not as the substance of
  the skill.
- Prefer inlining a small reusable template over copying a task-specific
  script wholesale. If a copied artifact only fits the original task, describe
  the pattern instead of shipping the artifact.

---

## A toolchain import carries a skill

Packaging a programming-language toolchain or package manager for the dk ecosystem
(for example `CommonsLang_Python` = CPython + uv, `CommonsLang_DotNet` = the .NET
SDK, `CommonsLang_OCaml` = OCaml + opam) must, in the same body of work, **add or
update a dk-ai skill that builds and ingests projects with that toolchain** —
materialize the runtime, resolve/lock dependencies, build, and assemble a runnable
project or dk package. The point is that a later request (a Prompt Studio mini-plan,
a GitHub `new-package` issue) drives the toolchain from a known-good recipe instead
of reverse-engineering it.

The skill must capture the **validated** end-to-end path: actually run the runtime,
create a lock, and build at least one real project — not merely confirm the package
distributes. A toolchain package is **not done** until that skill exists and its
lock/build path has been executed at least once. (Confirming `distribute` is green
is necessary but not sufficient: it proves the runtime materializes, not that the
`run`/`dialog` UI rules and the lock-then-build ingestion work.)

---

## Exercise the package's capabilities in its distribution scripts

A dk package's `dist-*.u` / `run.u` should not merely ship its objects — it should
**invoke the package's own capabilities**: a tool's `--version`, a `run`/`dialog`
round-trip, a solve/lock-then-build cycle. Each such invocation earns its keep twice:

- **Usage documentation** — the `## <Name>` section plus its recorded output renders
  as a worked *Usage* example in the generated package docs, so a consumer sees
  exactly how to drive the package.
- **Regression test** — the check re-runs on every tagged release (the distribute
  CI), so a capability that breaks fails the release instead of shipping broken.

So whenever a package exposes a runnable capability (a CLI, or a
solve/lock/build/ingest flow), add a dist-script section that exercises it end to end
against a tiny fixture. Test it by `run-function`ing the package's **`F_` function
rules** — a UI/dialog rule cannot be dist-tested (launching a program needs the
`run`/`write` trust caps and project files the distribute step does not grant), so its
heavy logic must live in `F_` function rules that the uirule delegates to. For
example, `CommonsLang_Python`'s dist scripts should `run-function` its lock + build
`F_` rules on a trivial requirement (e.g. `six`), which both documents the ingestion
Usage and regression-tests the lock-then-build path on every release. This complements —
does not replace — the one-time validation the toolchain skill must perform per the rule
above.

---

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

### UI-rule project-tree copies

When documenting or implementing dk UI-rule workflows that must copy a generated
file into the live project source tree:

1. Generate the file in the rule's temp area first.
2. Use `request.io.realpath(...)` to obtain the host-visible source path.
3. Use `request.ui.spawn` with a packaged cross-platform tool such as
   `Coreutils cp` to copy into the strictly-relative project-tree destination.
4. Do not rely on PowerShell-only copy helpers for this path.

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
- **Release state**: Distinguish finished packages from unfinished ones using `etc/dk/d/*.json`
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
- **Signing/release**: One-time `dk0 prepare-version` key setup with GitHub environment secrets for `dk-distribute`; back up the signing transcript in a password manager (simplest) or, for hardware security, encrypt it with `age` + `age-plugin-yubikey`

### convert-pypi-to-dk-package

- **Purpose**: Ingest a PyPI requirement set into a hermetic dk build with the `CommonsLang_Python` toolchain (bundled CPython 3.13 + uv)
- **Model**: Lock-then-build — `UvLock.Solve` resolves once (network) and pins each wheel per slot into `dk-uv-lock.jsonc`; `UvBuild.Build` fetches those wheels offline via `get-asset` and `uv pip install --no-index --offline`
- **Generator pattern**: The uirule stays thin and captures a checked-in Python generator/helper (real language, `tomllib`/`json`, testable off-dk); the dk0 side is the two-stage `request.ui.capture` pattern shared with `Solve`
- **uv 0.12 facts**: universal lockfile, no `uv export --python-platform`, `-o` name must be `pylock.toml` (no dots); per-slot wheel selection + Python-tag filtering done in the generator
- **dk0/lua-ml facts**: `--trust-local-caps run,write`; `capture` not `spawn`; `io.close` every continued object; no `gsub`/local-functions/booleans; `return M`
- **Validation rule**: Test the Python helpers standalone first (uv-managed 3.13), then local dk0 dialog, then tag CI

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
