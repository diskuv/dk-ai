param(
    [Parameter(Mandatory = $true)]
    [string]$PowerShellOutput,

    [Parameter(Mandatory = $true)]
    [string]$ShellOutput
)

$ErrorActionPreference = 'Stop'

function Normalize-Row {
    param([string]$Line)
    if ($Line -like '=== * ===') {
        $body = $Line.Substring(4, $Line.Length - 8)
        $body = $body -replace '^\.\\', ''
        $body = $body -replace '^\./', ''
        $body = $body -replace '\\', '/'
        return "=== $body ==="
    }
    if ($Line -match '^\.github/workflows/.*:\d+: ') {
        return $null
    }
    return $Line
}

function Get-NormalizedLines {
    param([string]$Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $text = $text -replace "`r`n", "`n"
    $rawLines = @($text -split "`n" | ForEach-Object { Normalize-Row $_ })
    $normalizedLines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $rawLines.Count; $i++) {
        $line = $rawLines[$i]
        if ($null -eq $line -or $line -eq '') {
            continue
        }
        $normalizedLines.Add($line)
    }
    while ($normalizedLines.Count -gt 0 -and $normalizedLines[$normalizedLines.Count - 1] -eq '') {
        $normalizedLines.RemoveAt($normalizedLines.Count - 1)
    }
    return @($normalizedLines | Sort-Object -Unique)
}

Write-Host "Loading PowerShell output: $PowerShellOutput"
if (-not (Test-Path $PowerShellOutput)) {
    Write-Error "PowerShell output file not found: $PowerShellOutput"
    exit 1
}
$psLines = Get-NormalizedLines $PowerShellOutput

Write-Host "Loading shell output: $ShellOutput"
if (-not (Test-Path $ShellOutput)) {
    Write-Error "Shell output file not found: $ShellOutput"
    exit 1
}
$shLines = Get-NormalizedLines $ShellOutput

Write-Host ""
Write-Host "PowerShell output: $($psLines.Count) lines"
Write-Host "Shell output: $($shLines.Count) lines"

$psHeaders = @($psLines | Where-Object { $_ -like '=== * ===' })
$shHeaders = @($shLines | Where-Object { $_ -like '=== * ===' })

Write-Host ""
Write-Host "PowerShell sections: $($psHeaders.Count)"
Write-Host "Shell sections: $($shHeaders.Count)"

if ($psHeaders.Count -ne $shHeaders.Count) {
    Write-Error "Section count mismatch!"
    exit 1
}

$headerDiff = Compare-Object $psHeaders $shHeaders -SyncWindow 0
if ($headerDiff) {
    Write-Error "Section header mismatch detected:"
    $headerDiff | Format-Table -AutoSize | Out-String | Write-Error
    exit 1
}

Write-Host "✓ Section headers match exactly"

$diff = Compare-Object $psLines $shLines -SyncWindow 0
if ($diff) {
    Write-Host ""
    Write-Host "Content differences detected:"
    $diff | Select-Object -First 20 | Format-Table -AutoSize | Out-String | Write-Host
    Write-Error "Content mismatch! Review above for details."
    exit 1
}

Write-Host "✓ File content matches exactly"
Write-Host ""
Write-Host "✅ All validations passed!"
Write-Host "PowerShell and shell outputs are equivalent."
