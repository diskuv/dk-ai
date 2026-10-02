param(
    [Parameter(Mandatory = $true)]
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
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

function Get-ValuesSamplerCommand {
    $jsScript = Join-Path $scriptRoot 'sample-output-paths.js'
    $pyScript = Join-Path $scriptRoot 'sample-output-paths.py'

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node -and (Test-Path -Path $jsScript -PathType Leaf)) {
        return @($node.Source, $jsScript)
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python -and (Test-Path -Path $pyScript -PathType Leaf)) {
        return @($python.Source, $pyScript)
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher -and (Test-Path -Path $pyScript -PathType Leaf)) {
        return @($pyLauncher.Source, '-3', $pyScript)
    }

    throw 'Neither Node.js nor Python is available for sampling values file outputs.'
}

function Get-WorkflowSamplerCommand {
    $jsScript = Join-Path $scriptRoot 'sample-workflow-durations.js'
    $pyScript = Join-Path $scriptRoot 'sample-workflow-durations.py'

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node -and (Test-Path -Path $jsScript -PathType Leaf)) {
        return @($node.Source, $jsScript)
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python -and (Test-Path -Path $pyScript -PathType Leaf)) {
        return @($python.Source, $pyScript)
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher -and (Test-Path -Path $pyScript -PathType Leaf)) {
        return @($pyLauncher.Source, '-3', $pyScript)
    }

    throw 'Neither Node.js nor Python is available for workflow-duration summarization.'
}

function Get-GitHubRepoSlugFromOrigin {
    $originUrl = (git config --get remote.origin.url 2>$null)
    if (-not $originUrl) {
        return $null
    }

    $m = [Regex]::Match($originUrl, '^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$')
    if ($m.Success) {
        return "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
    }

    $m = [Regex]::Match($originUrl, '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$')
    if ($m.Success) {
        return "$($m.Groups[1].Value)/$($m.Groups[2].Value)"
    }

    return $null
}

function Get-ModuleProseContextFromRunFiles {
    param(
        [string]$Module,
        [System.IO.FileInfo[]]$RunFiles
    )

    $escapedModule = [Regex]::Escape($Module)
    $commandPattern = "(?:get-object|install-object|enter-object|get-asset|get-bundle|post-object)\s+$escapedModule"

    foreach ($runFile in $RunFiles) {
        $lines = Get-Content -Encoding UTF8 $runFile.FullName
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -notmatch $commandPattern) {
                continue
            }

            $start = [Math]::Max(0, $i - 8)
            $contextLines = @()
            for ($j = $start; $j -lt $i; $j++) {
                $line = $lines[$j].Trim()
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -match '^#' -or $line -match '^\$' -or $line -match '^\\' -or $line -match '^---' -or $line -match '^```' -or $line -match '^[\{\}"]') {
                    continue
                }
                $contextLines += $line
            }

            if ($contextLines.Count -gt 0) {
                return ($contextLines -join ' | ')
            }
        }
    }

    return $null
}

$absOut = $outFilePath
$valuesSamplerCommand = Get-ValuesSamplerCommand

# 1. Detect whether this is a dk project via root dk.u
Write-Utf8 -Path $absOut -Lines @("=== DK PROJECT DETECTION ===")
if (Test-Path -Path "dk.u" -PathType Leaf) {
    Write-Utf8 -Path $absOut -Lines @(
        "IsDkProject: true",
        "RootDkU: dk.u"
    )
}
else {
    Write-Utf8 -Path $absOut -Lines @(
        "IsDkProject: false",
        "RootDkU: (not found)"
    )
}

# 2. Read dependency imports from root dk.u
Write-Utf8 -Path $absOut -Lines @("", "=== DEPENDENCIES (from root dk.u %% import) ===")
if (Test-Path -Path "dk.u" -PathType Leaf) {
    $imports = Get-Content -Path "dk.u" -Encoding UTF8 |
        Where-Object { $_ -match '^\s*%%\s+import(?:\s|$)' } |
        ForEach-Object { $_.Trim() }

    if ($imports) {
        Write-Utf8 -Path $absOut -Lines $imports
    }
    else {
        Write-Utf8 -Path $absOut -Lines @("(no %% import commands found in dk.u)")
    }
}
else {
    Write-Utf8 -Path $absOut -Lines @("(dk.u file not found)")
}

# 3. Find and scan all etc/dk/d/*.json files
Write-Utf8 -Path $absOut -Lines @("", "=== DIST VERSION FILES (etc/dk/d/*.json) ===")
$distVersionFiles = @()
if (Test-Path -Path "etc\dk\d" -PathType Container) {
    $distVersionFiles = Get-ChildItem -Path "etc\dk\d" -File -Filter "*.json" |
        Sort-Object { Get-RepoRelativePath $_.FullName }
}

if ($distVersionFiles) {
    foreach ($f in $distVersionFiles) {
        $rel = Get-RepoRelativePath $f.FullName
        Write-Utf8 -Path $absOut -Lines @($rel)
        Write-Utf8 -Path $absOut -Lines @("", "=== $rel ===")
        Write-Utf8 -Path $absOut -Lines (Get-Content -Encoding UTF8 $f.FullName)
    }
}
else {
    Write-Utf8 -Path $absOut -Lines @("(no etc/dk/d/*.json files found)")
}

# 4. Find and scan all dist-*.u/run.u files
Write-Utf8 -Path $absOut -Lines @("", "=== DIST-*.U/RUN.U FILES ===")
$distRunFiles = Get-ChildItem -Path . -Recurse -Filter "run.u" |
    Where-Object { $_.Directory.Name -match "^dist-.+\.u$" } |
    Sort-Object { Get-RepoRelativePath $_.FullName }

if ($distRunFiles) {
    foreach ($f in $distRunFiles) {
        $rel = Get-RepoRelativePath $f.FullName
        Write-Utf8 -Path $absOut -Lines @("", "=== $rel ===")
        Write-Utf8 -Path $absOut -Lines (Get-Content -Encoding UTF8 $f.FullName)
    }
}
else {
    Write-Utf8 -Path $absOut -Lines @("(no dist-*.u/run.u files found)")
}

# 5. Find and scan all etc/dk/v/*.values.{jsonc,lua} files
# Extract filenames from JSON outputs (sample up to 100)
Write-Utf8 -Path $absOut -Lines @("", "=== VALUES FILES (etc/dk/v/*.values.*) ===")
if (Test-Path -Path "etc/dk/v" -PathType Container) {
    $valuesFiles = Get-ChildItem -Path "etc/dk/v" -Recurse -Include "*.values.jsonc", "*.values.lua" |
        Sort-Object { Get-RepoRelativePath $_.FullName }
    
    if ($valuesFiles -and $valuesFiles.Count -gt 0) {
        if ($valuesFiles -is [System.IO.FileInfo]) {
            $valuesFiles = @($valuesFiles)
        }
        foreach ($f in $valuesFiles) {
            $rel = Get-RepoRelativePath $f.FullName
            Write-Utf8 -Path $absOut -Lines @("", "=== $rel ===")
            
            # Use the checked-in helper to extract a deterministic sample of output paths.
            try {
                $samplerOutput = & $valuesSamplerCommand[0] $valuesSamplerCommand[1..($valuesSamplerCommand.Count - 1)] $f.FullName 100 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw ($samplerOutput -join [Environment]::NewLine)
                }

                if (-not $samplerOutput -or $samplerOutput.Count -eq 0) {
                    Write-Utf8 -Path $absOut -Lines @('(no outputs found in forms array)')
                    continue
                }

                $totalLine = $samplerOutput[0]
                if ($totalLine -match '^TOTAL_PATHS=(\d+)$') {
                    $totalPaths = [int]$Matches[1]
                    if ($totalPaths -eq 0) {
                        Write-Utf8 -Path $absOut -Lines @('(no outputs found in forms array)')
                    }
                    else {
                        Write-Utf8 -Path $absOut -Lines @("Sample outputs (max 100 of $totalPaths total):")
                        if ($samplerOutput.Count -gt 1) {
                            Write-Utf8 -Path $absOut -Lines $samplerOutput[1..($samplerOutput.Count - 1)]
                        }
                    }
                }
                else {
                    throw "Unexpected sampler output: $totalLine"
                }
            }
            catch {
                Write-Utf8 -Path $absOut -Lines @("(error parsing JSON: $_)")
            }
        }
    }
    else {
        Write-Utf8 -Path $absOut -Lines @("(no *.values.jsonc or *.values.lua files found)")
    }
}
else {
    Write-Utf8 -Path $absOut -Lines @("(etc/dk/v directory not found)")
}

# 6. Capture expected GitHub workflow duration for release-tag runs
Write-Utf8 -Path $absOut -Lines @("", "=== GITHUB RELEASE WORKFLOW DURATION ===")
$gh = Get-Command gh -ErrorAction SilentlyContinue
$repoSlug = Get-GitHubRepoSlugFromOrigin
if (-not $repoSlug) {
    Write-Utf8 -Path $absOut -Lines @(
        'RepoSlug: (unavailable)',
        'DurationStatus: unavailable',
        'DurationReason: could not resolve GitHub repo slug from remote.origin.url'
    )
}
elseif (-not $gh) {
    Write-Utf8 -Path $absOut -Lines @(
        "RepoSlug: $repoSlug",
        'DurationStatus: unavailable',
        'DurationReason: gh CLI not found'
    )
}
else {
    try {
        $workflowSamplerCommand = Get-WorkflowSamplerCommand
        $tmpRuns = Join-Path $env:TEMP "analyze-dk-project-runs-$PID.json"
        try {
            & $gh.Source run list --repo $repoSlug --limit 50 --json databaseId,displayTitle,headBranch,workflowName,status,conclusion,event,createdAt,startedAt,updatedAt,url | Set-Content -Path $tmpRuns -Encoding UTF8
            $summaryOutput = & $workflowSamplerCommand[0] $workflowSamplerCommand[1..($workflowSamplerCommand.Count - 1)] $tmpRuns 5 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw ($summaryOutput -join [Environment]::NewLine)
            }

            Write-Utf8 -Path $absOut -Lines @("RepoSlug: $repoSlug", 'DurationStatus: available')
            foreach ($line in $summaryOutput) {
                if ($line -match '^SAMPLE_COUNT=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("SampleCount: $($Matches[1])")
                    continue
                }
                if ($line -match '^EXPECTED_DURATION_MINUTES=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("ExpectedDurationMinutes: $($Matches[1])")
                    continue
                }
                if ($line -match '^MIN_DURATION_MINUTES=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("MinDurationMinutes: $($Matches[1])")
                    continue
                }
                if ($line -match '^MAX_DURATION_MINUTES=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("MaxDurationMinutes: $($Matches[1])")
                    continue
                }
                if ($line -match '^MEDIAN_DURATION_MINUTES=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("MedianDurationMinutes: $($Matches[1])")
                    continue
                }
                if ($line -match '^P80_DURATION_MINUTES=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("P80DurationMinutes: $($Matches[1])")
                    continue
                }
                if ($line -match '^RECENT_RUN=(.+)$') {
                    Write-Utf8 -Path $absOut -Lines @("RecentRun: $($Matches[1])")
                }
            }
        }
        finally {
            if (Test-Path -Path $tmpRuns) {
                Remove-Item -Path $tmpRuns -Force
            }
        }
    }
    catch {
        Write-Utf8 -Path $absOut -Lines @(
            "RepoSlug: $repoSlug",
            'DurationStatus: unavailable',
            "DurationReason: $($_.ToString())"
        )
    }
}

# 7. Extract and summarize MODULE@VERSION references from run.u files
Write-Utf8 -Path $absOut -Lines @("", "=== MODULE@VERSION EXTRACTION SUMMARY ===")
$modulesSlots = @{}
$moduleCommands = @{}
$moduleProseContexts = @{}

foreach ($f in $distRunFiles) {
    $content = Get-Content -Encoding UTF8 $f.FullName -Raw
    
    # Look for value shell commands that reference MODULE@VERSION
    # Patterns: get-object, post-object, enter-object, install-object, get-asset, get-bundle
    
    # 1. get-object MODULE@VERSION -s SLOT and install-object, enter-object (all with -s option)
    $pattern = '(?:get-object|install-object|enter-object)\s+([A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+)\s+(?:-s|--slot)\s+([A-Za-z0-9_.-]+)'
    $regexMatches = [Regex]::Matches($content, $pattern)
    
    foreach ($match in $regexMatches) {
        $module = $match.Groups[1].Value
        $slot = $match.Groups[2].Value
        $cmd = $match.Groups[0].Value -split '\s' | Select-Object -First 1
        
        if (-not $modulesSlots.ContainsKey($module)) {
            $modulesSlots[$module] = @()
        }
        if ($slot -notin $modulesSlots[$module]) {
            $modulesSlots[$module] += $slot
        }
        
        if (-not $moduleCommands.ContainsKey($module)) {
            $moduleCommands[$module] = @()
        }
        if ($cmd -notin $moduleCommands[$module]) {
            $moduleCommands[$module] += $cmd
        }
        # Extract description from prose before the command
        $beforeText = $content.Substring(0, [Math]::Max(0, $match.Index))
        $lines = $beforeText -split '\n'
        $prose = @()
        $maxProseLines = 5  # Capture up to 5 lines of context
        $lineCount = 0
        for ($i = $lines.Count - 1; $i -ge 0 -and $lineCount -lt $maxProseLines; $i--) {
            $line = $lines[$i].Trim()
            if ([string]::IsNullOrWhiteSpace($line)) {
                # Allow empty lines but continue looking for prose
                if ($prose.Count -gt 0) {
                    break
                }
                continue
            }
            if ($line -match '^#+\s' -or $line -match '^```' -or $line -match '^---' -or $line -match '^\$') {
                # Stop at headers, code blocks, dividers, or shell prompts
                break
            }
            $prose = @($line) + $prose
            $lineCount++
        }
        
        if ($prose.Count -gt 0) {
            if (-not $moduleProseContexts.ContainsKey($module)) {
                $moduleProseContexts[$module] = @()
            }
            $proseText = ($prose -join ' ')
            if ($proseText -notin $moduleProseContexts[$module]) {
                $moduleProseContexts[$module] += $proseText
            }
        }
    }
    
    # 2. get-asset, get-bundle, post-object (no slot requirement)
    $pattern = '(?:get-asset|get-bundle|post-object)\s+([A-Za-z0-9_.-]+@[A-Za-z0-9._+-]+)'
    $regexMatches = [Regex]::Matches($content, $pattern)
    
    foreach ($match in $regexMatches) {
        $module = $match.Groups[1].Value
        $cmd = $match.Groups[0].Value -split '\s' | Select-Object -First 1
        
        if (-not $moduleCommands.ContainsKey($module)) {
            $moduleCommands[$module] = @()
        }
        if ($cmd -notin $moduleCommands[$module]) {
            $moduleCommands[$module] += $cmd
        }
        
        # Extract description from prose before the command
        $beforeText = $content.Substring(0, [Math]::Max(0, $match.Index))
        $lines = $beforeText -split '\n'
        $prose = @()
        $maxProseLines = 5  # Capture up to 5 lines of context
        $lineCount = 0
        for ($i = $lines.Count - 1; $i -ge 0 -and $lineCount -lt $maxProseLines; $i--) {
            $line = $lines[$i].Trim()
            if ([string]::IsNullOrWhiteSpace($line)) {
                # Allow empty lines but continue looking for prose
                if ($prose.Count -gt 0) {
                    break
                }
                continue
            }
            if ($line -match '^#+\s' -or $line -match '^```' -or $line -match '^---' -or $line -match '^\$') {
                # Stop at headers, code blocks, dividers, or shell prompts
                break
            }
            $prose = @($line) + $prose
            $lineCount++
        }
        
        if ($prose.Count -gt 0) {
            if (-not $moduleProseContexts.ContainsKey($module)) {
                $moduleProseContexts[$module] = @()
            }
            $proseText = ($prose -join ' ')
            if ($proseText -notin $moduleProseContexts[$module]) {
                $moduleProseContexts[$module] += $proseText
            }
        }
    }
}

# Output the extracted modules
foreach ($module in ($modulesSlots.Keys + $moduleCommands.Keys | Sort-Object -Unique)) {
    Write-Utf8 -Path $absOut -Lines @("", "Module: $module")
    
    if ($modulesSlots.ContainsKey($module)) {
        $slots = $modulesSlots[$module] | Sort-Object
        Write-Utf8 -Path $absOut -Lines @("Slots: $($slots -join ', ')")
    }
    
    if ($moduleCommands.ContainsKey($module)) {
        $cmds = $moduleCommands[$module] | Sort-Object
        Write-Utf8 -Path $absOut -Lines @("Commands: $($cmds -join ', ')")
    }
    
    if ($moduleProseContexts.ContainsKey($module)) {
        $contexts = $moduleProseContexts[$module] |
            Where-Object { $_ -and $_ -notmatch '^\\test\(pass\)' } |
            Select-Object -First 3
        if ($contexts.Count -gt 0) {
            Write-Utf8 -Path $absOut -Lines @("ProseContext: $($contexts -join ' || ')")
        }
        else {
            $fallbackProse = Get-ModuleProseContextFromRunFiles -Module $module -RunFiles $distRunFiles
            if ($fallbackProse) {
                Write-Utf8 -Path $absOut -Lines @("ProseContext: $fallbackProse")
            }
        }
    }
    else {
        $fallbackProse = Get-ModuleProseContextFromRunFiles -Module $module -RunFiles $distRunFiles
        if ($fallbackProse) {
            Write-Utf8 -Path $absOut -Lines @("ProseContext: $fallbackProse")
        }
    }
}

# get full path to $absOut, and write summary
Write-Host "Analysis complete. Output written to ``$absOut``."
Write-Host "Please provide the contents back to the agent before proceeding."
