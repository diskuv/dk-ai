# Testing the analyze-dk-project Skill

This document explains how to test the `analyze-dk-project` skill to ensure the
PowerShell and shell helpers produce equivalent output across platforms.

## Overview

The `analyze-dk-project` skill first determines whether a repository is a dk
project by checking for `dk.u` in the repository root. If the repository is a
dk project, it then identifies:
- Root `dk.u` classification
- Dependencies from `etc/dk/i` import directory
- Modules referenced in `dist-*.u/run.u` unified scripts
- Value shell commands (get-object, post-object, enter-object, install-object, get-asset, get-bundle)
- Slot information for each module
- Module descriptions from prose or configuration files

## Quick Start

1. **Prepare a test dk project** (or use an existing one like `https://github.com/dkpkg/CommonsBase_LLVM.git`)
2. **Run both helpers** against the same project
3. **Compare outputs** using the provided validation script

## Detailed Test Procedure

### Step 1: Clone a Test Repository

Use a real dk project to validate the skill. The `CommonsBase_LLVM` repository is a known good test case:

```powershell
# On Windows
$tempRoot = Join-Path $env:TEMP 'dk-ai-skill-tests'
if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Path $tempRoot | Out-Null }
Set-Location $tempRoot

# Clone test repo if not present
if (-not (Test-Path 'CommonsBase_LLVM')) {
    git clone https://github.com/dkpkg/CommonsBase_LLVM.git
}
Set-Location 'CommonsBase_LLVM'
```

### Step 2: Run the PowerShell Helper

```powershell
# Set skillPath to the location of the skill on your machine
$skillPath = "path\to\dk-ai\skills\analyze-dk-project"

Set-Location "path\to\test\CommonsBase_LLVM"
$outFile = Join-Path $env:TEMP 'analysis-ps1.txt'
powershell -ExecutionPolicy Bypass -File "$skillPath\analyze-project.ps1" -OutFile $outFile
```

### Step 3: Run the Shell Helper (Unix/macOS/WSL)

```bash
# Set skillPath to the location of the skill on your machine
skillPath="path/to/dk-ai/skills/analyze-dk-project"

cd "path/to/test/CommonsBase_LLVM"
outFile="${TMPDIR:-/tmp}/analysis-sh.txt"
sh "$skillPath/analyze-project.sh" "$outFile"
```

### Step 4: Validate Output

#### Check that critical files are included

Both outputs should contain:

1. **DK PROJECT DETECTION section** identifying whether root `dk.u` exists
2. **Dependencies section** with files from `etc/dk/i`
3. **DIST-*.U/RUN.U FILES section** listing all unified scripts
4. **VALUES FILES section** with `*.values.{jsonc,lua}` files
5. **MODULE@VERSION EXTRACTION SUMMARY** identifying modules and commands used

#### Compare with the test comparison script (Unix)

```bash
bash test-compare-outputs.sh /tmp/analysis-ps1.txt /tmp/analysis-sh.txt
```

Or (on Windows with Git Bash):

```bash
bash test-compare-outputs.sh /c/temp/analysis-ps1.txt /c/temp/analysis-sh.txt
```

## Expected Patterns

The skill should identify patterns like:

```
- IsDkProject: true
- RootDkU: dk.u
- get-object CommonsBase_Std@2.5.x -s Release.Windows_x86_64
- post-object SomeModule@1.0.0 -f output.json -- param=value
- enter-object DebugModule@1.0.0 -s Release.Agnostic
- install-object ToolModule@2.1.0 -s Release.Darwin_arm64 -d ${SLOT.request}
- get-asset BundleModule@1.5.0 some/asset/path -f output.zip
- get-bundle DistributionModule@3.0.0 -d dist-files
```

## Troubleshooting

### Encoding issues on Windows

If comparing outputs from PowerShell and shell scripts, ensure both use UTF-8 without BOM. The PowerShell script explicitly creates UTF-8 without BOM output files.

### Path handling differences

The scripts normalize paths using forward slashes (`/`) for consistency across platforms, as per dk standards.

### Empty sections

If a section is empty (e.g., no `dist-*.u` folders found), the script will note `(not found)` or `(no files found)`. This is expected behavior.

## Integration with Agents

When the `analyze-dk-project` skill is used by agents:

1. The agent calls the skill to classify the repository by root `dk.u`
2. The agent receives structured dk-project, module, dependency, and slot information
3. The agent uses this information to filter repositories and plan subsequent operations
4. The agent verifies that all critical information was extracted before proceeding

## Test Coverage

The skill testing should verify:

- [ ] Root `dk.u` classification is reported
- [ ] Dependency inventory from `etc/dk/i` is complete
- [ ] All `dist-*.u/run.u` files are discovered
- [ ] All `*.values.{jsonc,lua}` files are found
- [ ] Module names are correctly extracted from commands
- [ ] Slot names are correctly extracted from `-s` options
- [ ] Command types (get-object, post-object, etc.) are identified
- [ ] Descriptions are extracted from surrounding prose
- [ ] UTF-8 encoding is preserved
- [ ] Path normalization is consistent

---

**Note:** Tests should be run on both Windows (PowerShell) and Unix (shell) to ensure cross-platform compatibility.
