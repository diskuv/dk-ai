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

function Add-FileSection {
    param([string]$Path)
    $rel = Get-RepoRelativePath $Path
    Write-Utf8 -Path $outFilePath -Lines @("", "=== $rel ===")
    Write-Utf8 -Path $outFilePath -Lines (Get-Content -Encoding UTF8 $Path)
}

function Add-RepoRelativeFileSection {
    param([string]$RelativePath)
    $fullPath = Join-Path (Get-Location).Path ($RelativePath.Replace('/', '\'))
    Write-Utf8 -Path $outFilePath -Lines @("=== $RelativePath ===")
    Write-Utf8 -Path $outFilePath -Lines (Get-Content -Encoding UTF8 $fullPath)
}

function Test-RelevantValuesFile {
    param([string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    if ($name -like '*.Bundle.values.jsonc' -or
        $name -like '*Autoconf*.values.jsonc' -or
        $name -like '*Win32.LLVM_MinGW*.values.jsonc' -or
        $name -like 'Toolchain.W64dev*.values.jsonc' -or
        $name -like 'Toolchain.MinGW*.values.jsonc') {
        return $true
    }

    $patterns = @(
        '\./configure',
        'Toolchain\.W64dev',
        'Toolchain\.MinGW',
        'mingw-host-triplet'
    )
    foreach ($pattern in $patterns) {
        if (Select-String -Path $Path -Pattern $pattern -Quiet) {
            return $true
        }
    }
    return $false
}

Write-Utf8 -Path $outFilePath -Lines @("=== DK PROJECT DETECTION ===")
if (Test-Path -Path 'dk.u') {
    Write-Utf8 -Path $outFilePath -Lines @("IsDkProject: true", "RootDkU: dk.u")
}
else {
    Write-Utf8 -Path $outFilePath -Lines @("IsDkProject: false", "RootDkU: (not found)")
}

if (Test-Path -Path 'dk.u') {
    Add-FileSection -Path (Resolve-Path 'dk.u').Path
}

$distRunFiles = @()
if (Test-Path -Path '.') {
    $distRunFiles = Get-ChildItem -Path . -Recurse -File -Filter 'run.u' |
        Where-Object { $_.FullName -match '[\\/](dist-[^\\/]+\.u)[\\/]run\.u$' } |
        ForEach-Object { Get-RepoRelativePath $_.FullName }
    [Array]::Sort($distRunFiles, [System.StringComparer]::Ordinal)
}

Write-Utf8 -Path $outFilePath -Lines @("", "=== DIST-*.U/RUN.U FILES ===")
if ($distRunFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @("(not found)")
}
else {
    Write-Utf8 -Path $outFilePath -Lines $distRunFiles
    foreach ($file in $distRunFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

$valuesFiles = @()
if (Test-Path -Path 'etc\dk\v') {
    $valuesFiles = Get-ChildItem -Path 'etc\dk\v' -Recurse -File -Filter '*.values.jsonc' |
        Where-Object { Test-RelevantValuesFile -Path $_.FullName } |
        ForEach-Object { Get-RepoRelativePath $_.FullName }
    [Array]::Sort($valuesFiles, [System.StringComparer]::Ordinal)
}

Write-Utf8 -Path $outFilePath -Lines @("", "=== AUTOCONF-RELATED VALUES FILES ===")
if ($valuesFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @("(not found)")
}
else {
    Write-Utf8 -Path $outFilePath -Lines $valuesFiles
    foreach ($file in $valuesFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

Write-Host "Analysis complete. Output written to ``$outFilePath``."
Write-Host "Please provide the contents back to the agent before proceeding."
