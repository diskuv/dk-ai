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

function Append-FileSection {
    param([string]$Header, [string]$Path)
    Write-Utf8 -Path $outFilePath -Lines @("", "=== $Header ===")
    Write-Utf8 -Path $outFilePath -Lines (Get-Content -Encoding UTF8 $Path)
}

$skipDirRegex = [regex]'[\\/](?:\.git|_build|node_modules|\.opam|_opam|dist|\.direnv|\.venv|venv|target|bin|obj)(?:[\\/]|$)'
$allFiles = Get-ChildItem -Recurse -File |
    Where-Object { $_.FullName -notmatch $skipDirRegex }

$nowebFiles = $allFiles |
    Where-Object { $_.Extension -in @('.nw', '.noweb') } |
    Sort-Object { Get-RepoRelativePath $_.FullName }

$buildPatterns = @(
    'dune-project',
    'dune-workspace',
    'Makefile',
    'makefile',
    'GNUmakefile',
    'package.json',
    'pyproject.toml',
    'Cargo.toml',
    'go.mod',
    'pom.xml',
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    '.gitlab-ci.yml'
)

$rootBuildFiles = foreach ($name in $buildPatterns) {
    if (Test-Path -LiteralPath $name -PathType Leaf) {
        Get-Item -LiteralPath $name
    }
}

$recursiveBuildFiles =
    @(
        $allFiles | Where-Object { $_.Name -eq 'dune' }
        $allFiles | Where-Object { $_.Extension -eq '.opam' }
        $allFiles | Where-Object {
            $_.FullName -match '[\\/]\\.github[\\/]workflows[\\/]' -and
            $_.Extension -in @('.yml', '.yaml')
        }
    ) |
    Where-Object { $_ } |
    Sort-Object { Get-RepoRelativePath $_.FullName } -Unique

$unifiedHits = Select-String -Path ($allFiles | ForEach-Object FullName) `
    -Pattern 'U2Markdown|UCramRunner|UDuneImport|\.md\.ml\.u|\.ml\.u|promote|runtest' `
    -SimpleMatch:$false -ErrorAction SilentlyContinue

Write-Utf8 -Path $outFilePath -Lines @('=== noweb-files ===')
if ($nowebFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('<none found>')
}
else {
    Write-Utf8 -Path $outFilePath -Lines ($nowebFiles | ForEach-Object { Get-RepoRelativePath $_.FullName })
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== build-files ===')
$allBuildFiles = @($rootBuildFiles + $recursiveBuildFiles) | Sort-Object { Get-RepoRelativePath $_.FullName } -Unique
if ($allBuildFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('<none found>')
}
else {
    Write-Utf8 -Path $outFilePath -Lines ($allBuildFiles | ForEach-Object { Get-RepoRelativePath $_.FullName })
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== unified-search ===')
if (-not $unifiedHits) {
    Write-Utf8 -Path $outFilePath -Lines @('<no matches found>')
}
else {
    Write-Utf8 -Path $outFilePath -Lines ($unifiedHits | ForEach-Object {
        $rel = Get-RepoRelativePath $_.Path
        "${rel}:$($_.LineNumber):$($_.Line.TrimEnd())"
    })
}

foreach ($file in $allBuildFiles) {
    Append-FileSection -Header (Get-RepoRelativePath $file.FullName) -Path $file.FullName
}

foreach ($file in $nowebFiles) {
    Append-FileSection -Header (Get-RepoRelativePath $file.FullName) -Path $file.FullName
}

Write-Host "Analysis complete. Output written to ``$outFilePath``."
Write-Host "Please provide the contents back to the agent before proceeding."
