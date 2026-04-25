# Testing the analyze-dune-project Skill

This document explains how to test the `analyze-dune-project` skill to ensure the PowerShell and shell helpers produce equivalent output across platforms.

## Agent Integration

The `convert-expect-to-unified` agent now depends on this skill as a mandatory first step.

When testing the full migration workflow:

1. Invoke the `convert-expect-to-unified` agent.
2. Confirm it completes project analysis using `analyze-dune-project` before any migration output.
3. Confirm on Unix/Linux that unified-script output comparisons use `test-compare-outputs.sh`.

## Quick Start

1. **Prepare a test Dune project** (or use an existing one like `https://github.com/ocaml/ocaml-re.git`)
2. **Run both helpers** against the same project
3. **Compare outputs** using the provided validation script

## Detailed Test Procedure

### Step 1: Clone a Test Repository

Use a real OCaml/Dune project to validate the skill. The `ocaml-re` repository is a known good test case:

```powershell
# On Windows
$tempRoot = Join-Path $env:TEMP 'dk-ai-skill-tests'
if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Path $tempRoot | Out-Null }
Set-Location $tempRoot

# Clone test repo if not present
if (-not (Test-Path 'ocaml-re')) {
    git clone https://github.com/ocaml/ocaml-re.git
}
Set-Location 'ocaml-re'

# Checkout the known-good test commit for reproducibility
git checkout 22e5242444a9a6f63f90ace4eca99920f3ec7798
```

### Step 2: Run the PowerShell Helper

```powershell
# Set skillPath to the location of the skill on your machine
$skillPath = "path\to\dk-ai\skills\analyze-dune-project"

Set-Location "path\to\test\ocaml-re"
$outFile = Join-Path $env:TEMP 'analysis-ps1.txt'

powershell -ExecutionPolicy Bypass -File "$skillPath\analyze-project.ps1" -OutFile $outFile
Write-Host "PowerShell output: $outFile"
```

### Step 3: Run the Shell Helper

The shell helper requires a POSIX shell. On Windows, Git Bash is typically available at:

- `C:\Program Files\Git\bin\bash.exe`
- `C:\Program Files\Git\usr\bin\bash.exe`

```powershell
# Set skillPath to the location of the skill on your machine
$skillPath = "path\to\dk-ai\skills\analyze-dune-project"
$bashPath = "C:\Program Files\Git\bin\bash.exe"  # Adjust based on your Git installation
$outFile = Join-Path $env:TEMP 'analysis-sh.txt'

# Convert Windows path to Git Bash path format (e.g., C:\path → /c/path)
$skillPathBash = ($skillPath -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'
$outFileBash = ($outFile -replace '^([a-zA-Z]):', '/''$1') -replace '\\', '/'

& $bashPath -lc "cd /path/to/test/ocaml-re && `"$skillPathBash/analyze-project.sh`" `"$outFileBash`""
Write-Host "Shell output: $outFile"
```

### Step 4: Validate Output Equivalence

Use the provided comparison helper script to validate section ordering, content, and handle newline differences.

**On Windows:**

```powershell
# Set testDir to the location of the tests on your machine
$testDir = "path\to\dk-ai\tests\skills\analyze-dune-project"
$psOutput = Join-Path $env:TEMP 'analysis-ps1.txt'
$shOutput = Join-Path $env:TEMP 'analysis-sh.txt'

& "$testDir\test-compare-outputs.ps1" `
    -PowerShellOutput $psOutput `
    -ShellOutput $shOutput
```

**On Unix/Linux:**

```bash
# Set testDir to the location of the tests on your machine
testDir="path/to/dk-ai/tests/skills/analyze-dune-project"
bash "$testDir/test-compare-outputs.sh" \
    "/tmp/analysis-ps1.txt" \
    "/tmp/analysis-sh.txt"
```

The comparison script will:

- Verify both files have the same number of sections
- Confirm section headers are identical (after normalizing path separators)
- Verify file content is identical (ignoring line-ending differences)
- Report any real differences in ordering or content

## Expected Behavior

✅ **Section headers match** — After normalizing path separators (`.\` → ``, `\` → `/`), headers like `=== benchmarks/dune ===` should be identical in both outputs

✅ **Section ordering is identical** — Dune files are sorted alphabetically; ML files are sorted alphabetically within their directories

✅ **Content is identical** — File contents should match byte-for-byte, ignoring only line-ending differences (`LF` vs `CRLF`)

✅ **No repo pollution** — Neither helper should create `.convert-expect-to-unified` in the target repository or any other temporary files in the project

## Troubleshooting

### Git Bash Not Found on Windows

Run the helper script to find Git Bash:

```powershell
$candidates = @('C:\Program Files\Git\bin\sh.exe','C:\Program Files\Git\usr\bin\sh.exe','C:\Program Files\Git\bin\bash.exe')
$candidates | Where-Object { Test-Path $_ }
```

### Newline Mismatch Warnings

The comparison script handles `LF`/`CRLF` differences automatically. If newlines are flagged as a problem, see [CROSS_PLATFORM_NOTES.md](./CROSS_PLATFORM_NOTES.md).

### Section Headers Don't Match

This usually indicates a path normalization issue. Verify:

1. Paths use forward slashes (`/`) not backslashes (`\`)
2. Paths omit leading `.\` prefix
3. Both outputs sort files the same way (use `LC_ALL=C sort` semantics)

## Reference

All paths below are relative to the dk-ai repository root:

- **PowerShell helper:** `skills/analyze-dune-project/analyze-project.ps1`
- **Shell helper:** `skills/analyze-dune-project/analyze-project.sh`
- **Skill documentation:** `skills/analyze-dune-project/SKILL.md`
- **Agent:** `agents/convert-expect-to-unified.agent.md`
- **Comparison helpers:**
  - Windows: `tests/skills/analyze-dune-project/test-compare-outputs.ps1`
  - Unix/Linux: `tests/skills/analyze-dune-project/test-compare-outputs.sh`
- **Technical notes:** `tests/skills/analyze-dune-project/CROSS_PLATFORM_NOTES.md`
