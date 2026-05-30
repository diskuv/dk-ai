param(
    [string]$Node = 'node'
)

$ErrorActionPreference = 'Stop'

$root = Join-Path $env:TEMP ("dk-ai-workflow-run-test-" + [guid]::NewGuid().ToString('N'))
$checkout = Join-Path $root 'checkout'
$patchRoot = Join-Path $root 'patches'
New-Item -ItemType Directory -Path $checkout -Force | Out-Null
New-Item -ItemType Directory -Path $patchRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $checkout 'dist-demo.u') -Force | Out-Null
git init -q $checkout | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git init failed" }

[System.IO.File]::WriteAllText((Join-Path $checkout 'dk.u'), "%% import Foo`n")
[System.IO.File]::WriteAllText((Join-Path $checkout 'dist-demo.u\run.u'), "line 1`nold line`nline 3`n")

$patch = @'
--- dist-demo.u/run.u
+++ dist-demo.u/run.u.actual
@@ -1,3 +1,3 @@
 line 1
-old line
+new line
 line 3
'@
[System.IO.File]::WriteAllText((Join-Path $patchRoot 'demo.patch'), $patch)

try {
    $helper = Join-Path $PSScriptRoot '..\..\..\skills\analyze-dk-package-github-workflow-run\apply-workflow-patches.js'
    $first = & $Node $helper --checkout $checkout --patch-root $patchRoot
    if ($LASTEXITCODE -ne 0) { throw "helper failed on first run with exit code $LASTEXITCODE" }
    $second = & $Node $helper --checkout $checkout --patch-root $patchRoot
    if ($LASTEXITCODE -ne 0) { throw "helper failed on second run with exit code $LASTEXITCODE" }
    Write-Output '=== FIRST RUN ==='
    Write-Output $first
    Write-Output '=== SECOND RUN ==='
    Write-Output $second
    Write-Output '=== RESULT ==='
    Get-Content -Path (Join-Path $checkout 'dist-demo.u\run.u')
}
finally {
    Remove-Item -Path $root -Recurse -Force -ErrorAction SilentlyContinue
}
