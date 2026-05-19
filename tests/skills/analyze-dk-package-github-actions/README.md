# Testing the analyze-dk-package-github-actions Skill

This document explains how to test the
`analyze-dk-package-github-actions` skill and its helper scripts across
PowerShell and POSIX shell environments.

## Overview

The skill is meant to inspect a GitHub Actions-based dk package repository and
surface the facts needed to debug tag-driven distribution workflows.

The helper outputs should include:

- dk-project detection from root `dk.u`
- workflow inventory from `.github/workflows/*`
- `etc/dk/d/*.json` inventory and contents
- `dist-*.u/run.u` inventory and contents
- GitHub Actions highlight lines for common dk-package CI patterns

## Recommended test repository

Use `CommonsBase_FileMagic` or another dk package repository that has:

1. a root `dk.u`
2. `.github/workflows/*.yml`
3. `etc/dk/d/*.json`
4. `dist-*.u/run.u`

## Quick Start

1. Run the PowerShell helper against the same repository.
2. Run the shell helper against that repository.
3. Compare outputs with the provided validation scripts.

## Detailed Test Procedure

### Step 1: Run the PowerShell helper

```powershell
$skillPath = "path\to\dk-ai\skills\analyze-dk-package-github-actions"
$repoPath = "path\to\CommonsBase_FileMagic"
$outFile = Join-Path $env:TEMP 'analyze-dk-package-github-actions-ps1.txt'

Set-Location $repoPath
powershell -ExecutionPolicy Bypass -File "$skillPath\analyze-project.ps1" -OutFile $outFile
Write-Host "PowerShell output: $outFile"
```

### Step 2: Run the shell helper

On Windows, prefer Git Bash. On Unix, any POSIX shell is fine.

```powershell
$skillPath = "path\to\dk-ai\skills\analyze-dk-package-github-actions"
$repoPath = "path\to\CommonsBase_FileMagic"
$bashPath = "C:\Program Files\Git\bin\bash.exe"
$outFile = Join-Path $env:TEMP 'analyze-dk-package-github-actions-sh.txt'

$skillPathBash = ($skillPath -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'
$repoPathBash = ($repoPath -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'
$outFileBash = ($outFile -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'

& $bashPath -lc "cd `"$repoPathBash`" && `"$skillPathBash/analyze-project.sh`" `"$outFileBash`""
Write-Host "Shell output: $outFile"
```

### Step 3: Compare outputs

**Windows PowerShell**

```powershell
$testDir = "path\to\dk-ai\tests\skills\analyze-dk-package-github-actions"
$psOutput = Join-Path $env:TEMP 'analyze-dk-package-github-actions-ps1.txt'
$shOutput = Join-Path $env:TEMP 'analyze-dk-package-github-actions-sh.txt'

& "$testDir\test-compare-outputs.ps1" `
    -PowerShellOutput $psOutput `
    -ShellOutput $shOutput
```

**Unix/Linux**

```bash
testDir="path/to/dk-ai/tests/skills/analyze-dk-package-github-actions"
bash "$testDir/test-compare-outputs.sh" \
    "/tmp/analyze-dk-package-github-actions-ps1.txt" \
    "/tmp/analyze-dk-package-github-actions-sh.txt"
```

## Expected content

Both helper outputs should contain:

1. `=== DK PROJECT DETECTION ===`
2. `=== ROOT FILES ===`
3. `=== GITHUB ACTIONS WORKFLOWS ===`
4. `=== DIST VERSION FILES (etc/dk/d/*.json) ===`
5. `=== DIST-*.U/RUN.U FILES ===`
6. `=== GITHUB ACTIONS HIGHLIGHTS ===`

The highlights section should surface lines containing patterns such as:

- `push:`
- `tags:`
- `workflow_dispatch`
- `experimental-mlfront-ref`
- `diskuv/dk-distribute`
- `actions/download-artifact`
- `actions/upload-artifact`
- `softprops/action-gh-release`
- `combine`
- `distribute`

## Troubleshooting

### Git Bash not found on Windows

Try one of:

- `C:\Program Files\Git\bin\bash.exe`
- `C:\Program Files\Git\usr\bin\bash.exe`

### Output mismatch

Check for:

1. path normalization issues
2. different file ordering between PowerShell and shell
3. CRLF/LF mismatches in checked-in helper scripts

## Test Coverage

- [ ] Root `dk.u` classification is reported
- [ ] Workflow files are discovered
- [ ] `etc/dk/d/*.json` files are discovered
- [ ] `dist-*.u/run.u` files are discovered
- [ ] Workflow contents are included
- [ ] Highlights surface key GitHub Actions dk-package patterns
- [ ] UTF-8 encoding is preserved
- [ ] Path normalization is consistent
