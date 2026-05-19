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
    $lf = "`n"
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

function Get-FileLines {
    param([string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text -replace "`r`n", "`n"
    return @($text -split "`n", 0)
}

function Add-FileSection {
    param([string]$Path)
    $rel = Get-RepoRelativePath $Path
    Write-Utf8 -Path $outFilePath -Lines @("", "=== $rel ===")
    Write-Utf8 -Path $outFilePath -Lines (Get-FileLines $Path)
}

function Add-RepoRelativeFileSection {
    param([string]$RelativePath)
    $fullPath = Join-Path (Get-Location).Path ($RelativePath.Replace('/', '\'))
    Write-Utf8 -Path $outFilePath -Lines @("", "=== $RelativePath ===")
    Write-Utf8 -Path $outFilePath -Lines (Get-FileLines $fullPath)
}

function Get-OptionalRepoFile {
    param([string]$RelativePath)
    $candidate = Join-Path (Get-Location).Path ($RelativePath.Replace('/', '\'))
    if (Test-Path -Path $candidate -PathType Leaf) {
        return $RelativePath
    }
    return $null
}

function Get-HighlightLines {
    param([string[]]$WorkflowFiles)

    $patterns = @(
        '^\s*push:\s*$',
        '^\s*tags:\s*$',
        'workflow_dispatch',
        'experimental-mlfront-ref',
        'diskuv/dk-distribute',
        'actions/download-artifact',
        'actions/upload-artifact',
        'softprops/action-gh-release',
        '\bcombine\b',
        '\bdistribute\b',
        '\bgh run (list|view|watch|download)\b',
        '\bgh api\b'
    )

    $results = New-Object System.Collections.Generic.List[string]
    foreach ($relativePath in $WorkflowFiles) {
        $fullPath = Join-Path (Get-Location).Path ($relativePath.Replace('/', '\'))
        $matches = Select-String -Path $fullPath -Pattern $patterns -Encoding UTF8
        foreach ($match in $matches) {
            $line = '{0}:{1}: {2}' -f $relativePath, $match.LineNumber, $match.Line.Trim()
            $results.Add($line)
        }
    }
    return @($results | Sort-Object -Unique)
}

Write-Utf8 -Path $outFilePath -Lines @("=== DK PROJECT DETECTION ===")
if (Test-Path -Path 'dk.u' -PathType Leaf) {
    Write-Utf8 -Path $outFilePath -Lines @(
        'IsDkProject: true',
        'RootDkU: dk.u'
    )
}
else {
    Write-Utf8 -Path $outFilePath -Lines @(
        'IsDkProject: false',
        'RootDkU: (not found)'
    )
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== ROOT FILES ===')
$rootFiles = @()
foreach ($relativePath in @('dk.u', 'dk0', 'dk0.cmd', 'AGENTS.md')) {
    $found = Get-OptionalRepoFile -RelativePath $relativePath
    if ($found) {
        $rootFiles += $found
    }
}
if ($rootFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('(not found)')
}
else {
    foreach ($file in $rootFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== GITHUB ACTIONS WORKFLOWS ===')
$workflowFiles = @()
if (Test-Path -Path '.github\workflows' -PathType Container) {
    $workflowFiles = Get-ChildItem -Path '.github\workflows' -File |
        Where-Object { $_.Extension -in @('.yml', '.yaml') } |
        Sort-Object { Get-RepoRelativePath $_.FullName } |
        ForEach-Object { Get-RepoRelativePath $_.FullName }
}
if ($workflowFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('(not found)')
}
else {
    Write-Utf8 -Path $outFilePath -Lines $workflowFiles
    foreach ($file in $workflowFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== DIST VERSION FILES (etc/dk/d/*.json) ===')
$distJsonFiles = @()
if (Test-Path -Path 'etc\dk\d' -PathType Container) {
    $distJsonFiles = Get-ChildItem -Path 'etc\dk\d' -File -Filter '*.json' |
        Sort-Object { Get-RepoRelativePath $_.FullName } |
        ForEach-Object { Get-RepoRelativePath $_.FullName }
}
if ($distJsonFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('(not found)')
}
else {
    Write-Utf8 -Path $outFilePath -Lines $distJsonFiles
    foreach ($file in $distJsonFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== DIST-*.U/RUN.U FILES ===')
$distRunFiles = Get-ChildItem -Path . -Recurse -File -Filter 'run.u' |
    Where-Object { $_.FullName -match '[\\/](dist-[^\\/]+\.u)[\\/]run\.u$' } |
    Sort-Object { Get-RepoRelativePath $_.FullName } |
    ForEach-Object { Get-RepoRelativePath $_.FullName }
if ($distRunFiles.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('(not found)')
}
else {
    Write-Utf8 -Path $outFilePath -Lines $distRunFiles
    foreach ($file in $distRunFiles) {
        Add-RepoRelativeFileSection -RelativePath $file
    }
}

Write-Utf8 -Path $outFilePath -Lines @('', '=== GITHUB ACTIONS HIGHLIGHTS ===')
$highlights = Get-HighlightLines -WorkflowFiles $workflowFiles
if ($highlights.Count -eq 0) {
    Write-Utf8 -Path $outFilePath -Lines @('(no matching workflow lines found)')
}
else {
    Write-Utf8 -Path $outFilePath -Lines $highlights
}

Write-Host "Analysis complete. Output written to $outFilePath."
Write-Host 'Please provide the contents back to the agent before proceeding.'
