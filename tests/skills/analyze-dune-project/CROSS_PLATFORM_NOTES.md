# Cross-Platform Testing Notes for analyze-dune-project Skill

## Overview

The `analyze-dune-project` skill has both PowerShell and shell implementations that must produce semantically equivalent output across Windows and Unix platforms. This document captures the cross-platform issues discovered during testing and the validation approach.

## Key Issues and Solutions

### Issue 1: Path Separator Inconsistency (Windows vs Unix)

**Problem:**
- PowerShell's `Resolve-Path -Relative` returns paths with backslashes (`.\benchmarks\dune`)
- Shell's `find` and path manipulations return forward-slash paths (`benchmarks/dune`)
- This caused section headers to differ by platform: `=== .\lib\dune ===` vs `=== lib/dune ===`

**Solution:**
- PowerShell helper normalizes all paths to forward-slash format with the `Get-RepoRelativePath` helper function
- Removal of the `.\` prefix is handled separately in the normalization logic
- Both helpers now emit headers like `=== benchmarks/dune ===` consistently

**Code reference:**
- PowerShell: `Get-RepoRelativePath` function converts `\` to `/` and strips `.\`
- Shell: Uses standard `find` with path manipulation (`rel="${f#./}"`)

### Issue 2: File Sorting Order

**Problem:**
- PowerShell's `Get-ChildItem` with `Sort-Object FullName` sorts differently than shell's `find | LC_ALL=C sort`
- Example: PowerShell emits `benchmarks/dune` before `dune`, but shell emits `dune` first (due to POSIX `C` locale sorting)

**Solution:**
- Both helpers now use identical sorting key: `LC_ALL=C sort` semantics (C locale byte-order)
- PowerShell helper uses `Sort-Object` with the same relative path as the sort key
- Ensures section headers appear in the same order on both platforms

**Code reference:**
- PowerShell: `Get-ChildItem | Sort-Object { Get-RepoRelativePath $_.FullName }`
- Shell: `find . -type f -name dune | LC_ALL=C sort`

### Issue 3: UTF-8 Text Encoding

**Problem:**
- Windows PowerShell's default `Get-Content` does not always respect UTF-8-without-BOM files correctly
- Non-ASCII characters in OCaml source files were misinterpreted (e.g., `Ã¿` instead of the correct character)
- This caused content mismatches in files containing Unicode

**Solution:**
- Explicitly specify `-Encoding UTF8` for all `Get-Content` calls in PowerShell
- This ensures files are read as raw UTF-8 regardless of system settings

**Code reference:**
- PowerShell: `Get-Content -Encoding UTF8 $filePath`

### Issue 4: Line Endings (LF vs CRLF)

**Problem:**
- PowerShell's `[System.IO.File]::AppendAllText()` uses native system line endings
- Shell's output uses only `LF`
- On Windows, this creates `CRLF` in PowerShell output but `LF` in shell output

**Solution:**
- The validation script handles both line endings automatically by normalizing to `LF` before comparison
- This is not considered a failure because both files are functionally correct in their platform contexts

**Important:** Do NOT try to force identical line endings. Let each platform use its native format.

## Testing Approach

### Step 1: Test Against a Real Dune Project

Use `https://github.com/ocaml/ocaml-re.git` as a reference project because:
- It has multiple `dune` files at different directory levels
- It contains `.ml` files with `let%expect_test` patterns
- It has UTF-8 characters in OCaml source code
- It's publicly available for reproducibility

### Step 2: Validate Output Using test-compare-outputs.ps1

The comparison script normalizes both outputs before comparison:

1. **Path normalization:** Converts `.\path\to\file` → `path/to/file`
2. **Line ending normalization:** Converts `CRLF` → `LF`
3. **Header comparison:** Verifies section headers match after normalization
4. **Content comparison:** Verifies file content matches exactly

### Step 3: Check for Repository Pollution

Ensure neither helper leaves behind temporary files:
```powershell
# After running both helpers, verify:
git status --short
# Should show no changes in the tested repository
```

The helpers must NOT create `.make-literate-tests/` or other temporary directories in the project.

## Finding Git Bash on Windows

If the shell helper needs to be tested on Windows, Git Bash must be located. Common paths:

```powershell
$candidates = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\bash.exe',
    'C:\Program Files\Git\bin\sh.exe',
    'C:\Program Files\Git\usr\bin\sh.exe',
    'C:\Program Files (x86)\Git\bin\bash.exe'
)

$gitBash = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($gitBash) {
    Write-Host "Found Git Bash: $gitBash"
} else {
    Write-Host "Git Bash not found. Install 'Git for Windows' from https://git-scm.com/download/win"
}
```

## Lessons Learned

1. **Always normalize paths early** — Platform-specific path formatting can hide real differences
2. **Respect platform defaults for line endings** — Don't try to force cross-platform line ending uniformity in test validation
3. **Explicitly specify text encoding** — Never rely on system defaults for UTF-8 files
4. **Use stable sort semantics** — Both platforms should sort files using the same collation order (`LC_ALL=C`)
5. **Test with Unicode content** — Ensure encoding handling works with real-world non-ASCII characters
6. **Automate the comparison** — Manual diff comparison misses subtle encoding or ordering issues

## Future Improvements

- Consider adding a CI/CD job that runs this skill's helpers on both Windows and Unix agents
- Add the comparison script to the repository's test suite
- Document expected output format in the skill's SKILL.md file
