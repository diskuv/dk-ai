# Testing the make-dk-package-from-autoconf Skill

This document explains how to test the `make-dk-package-from-autoconf` skill and
its helper scripts across Windows PowerShell and POSIX shell environments.

## Overview

The skill is meant to help create or extend dk packages for autoconf-based
upstream projects. It requires the agent to inspect:

- `dk.u` in the repository root
- `dist-*.u/run.u`, especially `dist-win32.u/run.u`
- Primary package `*.values.jsonc` files
- Package `*.Bundle.values.jsonc` source-asset modules
- Existing autoconf and Windows cross-compilation reference files

The PowerShell and shell helpers should produce structurally equivalent analysis
output from the same repository.

## Recommended test repository

Use `CommonsBase_GNU` because it already contains:

- `Make.Autoconf.values.jsonc`
- `Make.Win32.LLVM_MinGW.values.jsonc`
- `Toolchain.W64devkit.values.jsonc`
- `dist-win32.u/run.u`

## Quick Start

1. Run the PowerShell helper against `CommonsBase_GNU`
2. Run the shell helper against the same checkout
3. Compare outputs with the provided validation scripts

## Detailed Test Procedure

### Step 1: Run the PowerShell helper

```powershell
$skillPath = "path\to\dk-ai\skills\make-dk-package-from-autoconf"
$repoPath = "path\to\CommonsBase_GNU"
$outFile = Join-Path $env:TEMP 'make-dk-package-from-autoconf-ps1.txt'

Set-Location $repoPath
powershell -ExecutionPolicy Bypass -File "$skillPath\analyze-project.ps1" -OutFile $outFile
Write-Host "PowerShell output: $outFile"
```

### Step 2: Run the shell helper

On Windows, prefer Git Bash. On Unix, any POSIX shell is fine.

```powershell
$skillPath = "path\to\dk-ai\skills\make-dk-package-from-autoconf"
$repoPath = "path\to\CommonsBase_GNU"
$bashPath = "C:\Program Files\Git\bin\bash.exe"
$outFile = Join-Path $env:TEMP 'make-dk-package-from-autoconf-sh.txt'

$skillPathBash = ($skillPath -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'
$repoPathBash = ($repoPath -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'
$outFileBash = ($outFile -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'

& $bashPath -lc "cd `"$repoPathBash`" && `"$skillPathBash/analyze-project.sh`" `"$outFileBash`""
Write-Host "Shell output: $outFile"
```

### Step 3: Compare outputs

**Windows PowerShell**

```powershell
$testDir = "path\to\dk-ai\tests\skills\make-dk-package-from-autoconf"
$psOutput = Join-Path $env:TEMP 'make-dk-package-from-autoconf-ps1.txt'
$shOutput = Join-Path $env:TEMP 'make-dk-package-from-autoconf-sh.txt'

& "$testDir\test-compare-outputs.ps1" `
    -PowerShellOutput $psOutput `
    -ShellOutput $shOutput
```

**Unix/Linux**

```bash
testDir="path/to/dk-ai/tests/skills/make-dk-package-from-autoconf"
bash "$testDir/test-compare-outputs.sh" \
    "/tmp/make-dk-package-from-autoconf-ps1.txt" \
    "/tmp/make-dk-package-from-autoconf-sh.txt"
```

## Expected content

Both helper outputs should contain:

1. `=== DK PROJECT DETECTION ===`
2. `=== DIST-*.U/RUN.U FILES ===`
3. `=== AUTOCONF-RELATED VALUES FILES ===`
4. The same ordered list of discovered files
5. Normalized relative paths using forward slashes in section headers

## Platform validation expectations

The skill guidance itself should clearly state:

- Windows `Release.Windows_*` slots are cross-compiles from the current Windows execution ABI
- Windows recipes must prepend the extracted `CommonsBase_LLVM.Toolchain.MinGW@21.1.8+rev-20251216` `bin` directory to `PATH` so MinGW compiler driver names resolve during `configure` and `make`
- Windows recipes may stack multiple `<PATH` envmods; each one prepends to `PATH`, which is the preferred way to expose both W64dev and LLVM-MinGW tools by name
- Windows recipes should pin `LD`, `AR`, `RANLIB`, `GREP`, `EGREP`, `FGREP`, `EGREP_TRADITIONAL`, `SED`, `AWK`, and `M4` with `+NAME=...` envmods when autoconf does not reliably discover them by PATH lookup alone
- When a `./configure`-generated file still contains raw backslash-heavy Windows paths, the skill should first prefer tool-name envvars plus PATH exposure, and only then use GNU `sed --in-place` to repair generated files; use `sed -f FILE --in-place` to avoid quoting issues
- Recipe commands should be hermetic and should not invoke host `powershell`; rely on declared tools and packaged shell/toolchain commands instead
- Source archives belong in `*.Bundle.values.jsonc`
- GNU source archives in `*.Bundle.values.jsonc` should use at least 10 geographically dispersed mirrors in their GNU origin listing
- After adding or changing `dk.u` assets, run `Shell.exe update` in development checkouts (or `./dk0 update` otherwise) before consuming those assets
- Reusable repo-local assets should be exposed through an asset library in `dk.u`, using the workspace script's library cell rather than `root` or the deprecated `dk0` cell
- 32-bit GnuWin32 bootstrap binaries may be exposed for `Release.Windows_x86`, `Release.Windows_x86_64`, and `Release.Windows_arm64` when they are only host-side tools, following the same copy-to-`${SLOT.request}/bin` pattern as `CommonsBase_GNU.Grep@2.5.4+gnuwin32-20090213`
- Linux validation should use Docker, WSL2, or a Linux host
- macOS validation should use a macOS machine or CI when no macOS host is available
- `dist-win32.u/run.u` must be updated with package-specific prose and working examples

## Troubleshooting

### Git Bash not found on Windows

Try one of:

- `C:\Program Files\Git\bin\bash.exe`
- `C:\Program Files\Git\usr\bin\bash.exe`

### Output mismatch

Check for:

1. Path normalization issues
2. Different file ordering between PowerShell and shell
3. Missing `realpath` or shell tool differences on Windows

## References

- Skill documentation: `skills/make-dk-package-from-autoconf/SKILL.md`
- PowerShell helper: `skills/make-dk-package-from-autoconf/analyze-project.ps1`
- Shell helper: `skills/make-dk-package-from-autoconf/analyze-project.sh`
- Windows comparison script: `tests/skills/make-dk-package-from-autoconf/test-compare-outputs.ps1`
- Unix comparison script: `tests/skills/make-dk-package-from-autoconf/test-compare-outputs.sh`
