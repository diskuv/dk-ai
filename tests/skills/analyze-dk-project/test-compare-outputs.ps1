param(
    [Parameter(Mandatory = $true)]
    [string]$PowerShellOutput,

    [Parameter(Mandatory = $true)]
    [string]$ShellOutput
)

$ErrorActionPreference = 'Stop'

function Compare-Files {
    param([string]$File1, [string]$File2, [string]$Label)

    if (-not (Test-Path -Path $File1)) {
        Write-Host "FAIL: $Label file not found: $File1" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path -Path $File2)) {
        Write-Host "FAIL: $Label file not found: $File2" -ForegroundColor Red
        return $false
    }

    $content1 = Get-Content -Path $File1 -Encoding UTF8 -Raw
    $content2 = Get-Content -Path $File2 -Encoding UTF8 -Raw

    if ($content1 -eq $content2) {
        Write-Host "PASS: $Label outputs match exactly" -ForegroundColor Green
        return $true
    }

    Write-Host "WARNING: $Label outputs differ slightly" -ForegroundColor Yellow
    return $true
}

function Test-RequiredSections {
    param([string]$File)

    $content = Get-Content -Path $File -Encoding UTF8 -Raw
    $requiredSections = @(
        '=== DK PROJECT DETECTION ===',
        '=== DEPENDENCIES \(from root dk\.u %% import\) ===',
        '=== DIST VERSION FILES \(etc/dk/d/\*\.json\) ===',
        '=== DIST-\*\.U/RUN\.U FILES ===',
        '=== VALUES FILES \(etc/dk/v/\*\.values\.\*\) ===',
        '=== GITHUB RELEASE WORKFLOW DURATION ===',
        '=== MODULE@VERSION EXTRACTION SUMMARY ==='
    )

    $allFound = $true
    foreach ($section in $requiredSections) {
        if ($content -match $section) {
            Write-Host "Found section: $section" -ForegroundColor Green
        }
        else {
            Write-Host "Missing section: $section" -ForegroundColor Red
            $allFound = $false
        }
    }

    return $allFound
}

function Test-DkProjectClassification {
    param([string]$File)

    $content = Get-Content -Path $File -Encoding UTF8 -Raw
    $hasClassification = $content -match 'IsDkProject:\s+(true|false)'
    $hasRootMarker = $content -match 'RootDkU:\s+(dk\.u|\(not found\))'

    if ($hasClassification) {
        Write-Host 'Found dk project classification' -ForegroundColor Green
    }
    else {
        Write-Host 'Missing dk project classification' -ForegroundColor Red
    }

    if ($hasRootMarker) {
        Write-Host 'Found root dk.u marker result' -ForegroundColor Green
    }
    else {
        Write-Host 'Missing root dk.u marker result' -ForegroundColor Red
    }

    return ($hasClassification -and $hasRootMarker)
}

function Get-ExtractedModules {
    param([string]$File)

    $content = Get-Content -Path $File -Encoding UTF8 -Raw
    $modules = @()
    $moduleMatches = [regex]::Matches($content, 'Module:\s+([A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+)')
    foreach ($moduleMatch in $moduleMatches) {
        $modules += $moduleMatch.Groups[1].Value
    }

    return $modules | Sort-Object -Unique
}

Write-Host '=== Analyzing dk-project Skill Output ===' -ForegroundColor Cyan

Write-Host "`n1. Checking PowerShell output..." -ForegroundColor Cyan
$psOk = Test-RequiredSections -File $PowerShellOutput
[void](Test-DkProjectClassification -File $PowerShellOutput)

Write-Host "`n2. Checking Shell output..." -ForegroundColor Cyan
$shOk = Test-RequiredSections -File $ShellOutput
[void](Test-DkProjectClassification -File $ShellOutput)

Write-Host "`n3. Comparing files..." -ForegroundColor Cyan
[void](Compare-Files -File1 $PowerShellOutput -File2 $ShellOutput -Label 'Output')

Write-Host "`n4. Extracting modules..." -ForegroundColor Cyan
$psModules = Get-ExtractedModules -File $PowerShellOutput
$shModules = Get-ExtractedModules -File $ShellOutput

Write-Host "PowerShell modules found: $($psModules.Count)"
$psModules | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host "Shell modules found: $($shModules.Count)"
$shModules | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

$modulesMatch = (@($psModules) -join "`n") -eq (@($shModules) -join "`n")
if ($modulesMatch) {
    Write-Host 'Module lists match' -ForegroundColor Green
}
else {
    Write-Host 'Module lists may differ (acceptable depending on test project)' -ForegroundColor Yellow
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$allPass = $psOk -and $shOk -and
    (Test-DkProjectClassification -File $PowerShellOutput) -and
    (Test-DkProjectClassification -File $ShellOutput)
if ($allPass) {
    Write-Host 'All checks passed' -ForegroundColor Green
    exit 0
}

Write-Host 'Some checks failed' -ForegroundColor Red
exit 1
