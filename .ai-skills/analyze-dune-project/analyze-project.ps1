param(
    [Parameter(Mandatory = $true)]
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$outFilePath = [System.IO.Path]::GetFullPath($OutFile)
$outDir = Split-Path -Parent $outFilePath
if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path -Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# Create/empty the output file with UTF-8 (no BOM) encoding
[System.IO.File]::WriteAllText($outFilePath, "", $utf8NoBom)

function Write-Utf8 {
    param([string]$Path, [string[]]$Lines)
    $enc = New-Object System.Text.UTF8Encoding($false)
    $lf = [char]10
    [System.IO.File]::AppendAllText($Path, (($Lines -join $lf) + $lf), $enc)
}

function Get-RepoRelativePath {
    param([string]$Path)
    $relativePath = Resolve-Path -Relative $Path
    if ($relativePath.StartsWith('.\')) {
        $relativePath = $relativePath.Substring(2)
    }
    elseif ($relativePath.StartsWith('./')) {
        $relativePath = $relativePath.Substring(2)
    }
    return $relativePath.Replace('\', '/')
}

$absOut = $outFilePath

Write-Utf8 -Path $absOut -Lines @("=== dune-project ===")
Write-Utf8 -Path $absOut -Lines (Get-Content -Encoding UTF8 dune-project)

Get-ChildItem -Recurse -Filter "dune" |
    Sort-Object { Get-RepoRelativePath $_.FullName } |
    ForEach-Object {
    $rel = Get-RepoRelativePath $_.FullName
    Write-Utf8 -Path $absOut -Lines @("", "=== $rel ===")
    Write-Utf8 -Path $absOut -Lines (Get-Content -Encoding UTF8 $_.FullName)
}

# 1. Find directories containing .ml files with "let%expect_test"
$expectDirs = Get-ChildItem -Recurse -Filter "*.ml" |
    Where-Object { Select-String -Pattern "let%expect_test" -Path $_.FullName -Quiet } |
    ForEach-Object { $_.DirectoryName } |
    Sort-Object -Unique

# 2. Recursively collect _all_ .ml files in those directories.
# There may be test support files that don't have "let%expect_test",
# but we expect them to co-reside in the same directories as the expect tests.
$mlFiles = @()
foreach ($d in $expectDirs) {
    $mlFiles += Get-ChildItem -Path $d -Recurse -Filter "*.ml" -File
}
$mlFiles = $mlFiles | Sort-Object { Get-RepoRelativePath $_.FullName } -Unique

foreach ($f in $mlFiles) {
    $rel = Get-RepoRelativePath $f.FullName
    Write-Utf8 -Path $absOut -Lines @("", "=== $rel ===")
    Write-Utf8 -Path $absOut -Lines (Get-Content -Encoding UTF8 $f.FullName)
}

# get full path to $absOut, and write summary
Write-Host "Analysis complete. Output written to ``$absOut``."
Write-Host "Please provide the contents back to the agent before proceeding."
