param(
    [Parameter(Mandatory = $true)]
    [string]$RunId,

    [Parameter(Mandatory = $true)]
    [string]$CheckoutPath,

    [string]$Repository
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$helper = Join-Path $scriptRoot 'apply-workflow-patches.js'
if (-not (Test-Path -Path $helper -PathType Leaf)) {
    throw "Missing helper script: $helper"
}

function Invoke-NativeChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    $output = & $Command
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "$Description failed with exit code $exitCode."
    }

    return $output
}

$checkout = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CheckoutPath).Path)
if (-not (Test-Path -Path (Join-Path $checkout 'dk.u') -PathType Leaf)) {
    throw "Missing dk.u in checkout root: $checkout"
}

function Get-RepositorySlug {
    param([string]$CheckoutRoot)

    if ($Repository) {
        return $Repository
    }

    $remote = Invoke-NativeChecked -Description "git remote get-url origin" -Command { git -C $CheckoutRoot remote get-url origin 2>$null }
    if (-not $remote) {
        throw "Repository slug was not provided and origin remote could not be resolved."
    }

    if ($remote -match '^git@[^:]+:(.+?)(?:\.git)?$') {
        return $Matches[1] -replace '\.git$', ''
    }
    if ($remote -match '^https?://[^/]+/(.+?)(?:\.git)?$') {
        return $Matches[1] -replace '\.git$', ''
    }
    if ($remote -match '^ssh://git@[^/]+/(.+?)(?:\.git)?$') {
        return $Matches[1] -replace '\.git$', ''
    }

    throw "Could not derive a GitHub repository slug from origin remote: $remote"
}

$repoSlug = Get-RepositorySlug -CheckoutRoot $checkout
$repoParts = $repoSlug -split '/', 2
if ($repoParts.Count -ne 2) {
    throw "Could not split repository slug into owner and repository name: $repoSlug"
}
$owner = $repoParts[0]
$repoName = $repoParts[1]

$workflowIdQuery = '.workflow_id'
$workflowId = Invoke-NativeChecked -Description "gh api workflow run details" -Command { gh api "repos/$repoSlug/actions/runs/$RunId" --jq $workflowIdQuery }
if ([string]::IsNullOrWhiteSpace($workflowId)) {
    throw "Could not determine workflow id for run $RunId in $repoSlug."
}

Write-Output 'GitHub workflow run:'
Write-Output "- owner: $owner"
Write-Output "- repository: $repoName"
Write-Output "- workflow id: $workflowId"
Write-Output "- run id: $RunId"

$artifactQuery = '.artifacts[] | select(.name == "patches") | [.id, .archive_download_url] | @tsv'
$artifactLines = @(Invoke-NativeChecked -Description "gh api artifacts listing" -Command { gh api "repos/$repoSlug/actions/runs/$RunId/artifacts" --paginate --jq $artifactQuery })
if ($artifactLines.Count -eq 0) {
    throw "No artifacts named 'patches' were found for run $RunId in $repoSlug."
}

$artifactRecords = foreach ($line in $artifactLines) {
    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }
    $parts = $line -split "`t", 2
    if ($parts.Count -ne 2) {
        throw "Unexpected artifact record: $line"
    }
    [pscustomobject]@{
        id = $parts[0]
        archive_download_url = $parts[1]
    }
}

$tempRoot = Join-Path $env:TEMP ("dk-ai-workflow-run-$RunId-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$patchExitCode = 0

try {
    $token = Invoke-NativeChecked -Description "gh auth token" -Command { gh auth token }
    foreach ($artifact in $artifactRecords) {
        $artifactId = $artifact.id
        $artifactUrl = $artifact.archive_download_url
        $zipFile = Join-Path $tempRoot "artifact-$artifactId.zip"
        $extractDir = Join-Path $tempRoot "artifact-$artifactId"
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

        Invoke-NativeChecked -Description "curl download for artifact $artifactId" -Command {
            curl.exe -sS -f -L -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" -o $zipFile $artifactUrl | Out-Null
        }
        Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force
    }

    & node $helper --checkout $checkout --patch-root $tempRoot
    $patchExitCode = $LASTEXITCODE
    if ($patchExitCode -ne 0 -and $patchExitCode -ne 1) {
        throw "Patch application failed with exit code $patchExitCode."
    }
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

if ($patchExitCode -ne 0) {
    exit $patchExitCode
}
