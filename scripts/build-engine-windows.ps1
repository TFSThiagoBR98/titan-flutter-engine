[CmdletBinding()]
param(
    [ValidateSet('host', 'android')]
    [string]$Kind = 'host',
    [ValidateSet('debug', 'profile', 'release')]
    [string]$Mode = 'debug',
    [ValidateSet('x64', 'arm64')]
    [string]$Cpu = 'x64',
    [ValidateSet('arm', 'arm64', 'x64')]
    [string]$AndroidCpu = 'arm',
    [string]$OutName,
    [ValidateRange(1, 1024)]
    [int]$Jobs = 4,
    [ValidateRange(1, 1024)]
    [int]$Load = 0,
    [string]$WorkDir = $env:TITAN_WORK_DIR,
    [string[]]$NinjaTarget = @()
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'build-engine-windows.ps1 must run on Windows'
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($WorkDir)) {
    $WorkDir = Join-Path $repositoryRoot '.build_flutter'
}
$flutterDirectory = Join-Path $WorkDir 'flutter'
$engineRoot = Join-Path $flutterDirectory 'engine/src'
$patchRoot = Join-Path $repositoryRoot 'patches'
$seriesFile = Join-Path $patchRoot 'series'
$flutterLock = Join-Path $repositoryRoot 'flutter.lock'
$flutterCommit = (Select-String -Path $flutterLock -Pattern '^flutter_commit=').Line -replace '^flutter_commit=', ''
if ([string]::IsNullOrWhiteSpace($flutterCommit)) {
    throw 'flutter.lock is missing flutter_commit'
}
if (-not (Test-Path (Join-Path $flutterDirectory '.git'))) {
    throw "Flutter checkout is missing: $flutterDirectory"
}

function Invoke-Git {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git failed with exit code $LASTEXITCODE"
    }
}

function Apply-PatchSeries {
    $pythonCommand = if ($env:TITAN_PYTHON) { $env:TITAN_PYTHON } else { 'python' }
    $folders = & $pythonCommand (Join-Path $repositoryRoot 'scripts/patch_series.py') --series $seriesFile --all
    if ($LASTEXITCODE -ne 0) {
        throw 'patch_series.py failed'
    }
    foreach ($folder in $folders) {
        $folderPath = Join-Path $patchRoot $folder
        $patches = Get-ChildItem -Path $folderPath -Filter '*.patch' -File | Sort-Object Name
        foreach ($patch in $patches) {
            $firstLine = (Get-Content -Path $patch.FullName -TotalCount 1)
            $patchRepository = '.'
            if ($firstLine -like '# Repo: *') {
                $patchRepository = $firstLine.Substring(8)
            }
            $patchCheckout = if ($patchRepository -eq '.') {
                $flutterDirectory
            } else {
                Join-Path $flutterDirectory $patchRepository
            }
            if (-not (Test-Path $patchCheckout)) {
                throw "patch repository is missing: $patchRepository"
            }
            Invoke-Git @('-C', $patchCheckout, 'apply', $patch.FullName)
        }
    }
}

$status = & git -C $flutterDirectory status --porcelain
if ($LASTEXITCODE -ne 0) {
    throw 'cannot inspect the Flutter checkout'
}
if (-not [string]::IsNullOrWhiteSpace(($status -join ''))) {
    throw "Flutter checkout has local changes: $flutterDirectory"
}
Apply-PatchSeries

if ([string]::IsNullOrWhiteSpace($OutName)) {
    if ($Kind -eq 'host') {
        $OutName = if ($Cpu -eq 'arm64') { "host_${Mode}_arm64" } else { "host_$Mode" }
    } else {
        $OutName = "android_${Mode}_$AndroidCpu"
    }
}

$gnArguments = @(
    '--target-dir', $OutName,
    '--runtime-mode', $Mode,
    '--no-lto',
    '--no-goma',
    '--rbe'
)
if ($Kind -eq 'host' -and $Cpu -eq 'arm64') {
    $gnArguments += @('--windows-cpu', 'arm64')
}
$ninjaTargets = @()
if ($Kind -eq 'host') {
    if ($Mode -eq 'debug') {
        $ninjaTargets = @(
            'flutter/build/archives:artifacts',
            'flutter/build/archives:embedder',
            'flutter/tools/font_subset',
            'flutter/build/archives:dart_sdk_archive',
            'flutter/shell/platform/windows/client_wrapper:client_wrapper_archive',
            'flutter/build/archives:windows_flutter',
            'flutter/impeller/toolkit/interop:sdk'
        )
    } else {
        $ninjaTargets = @('windows', 'gen_snapshot', 'flutter/build/archives:windows_flutter')
    }
} else {
    $gnArguments += '--android'
    if ($AndroidCpu -ne 'arm') {
        $gnArguments += "--android-cpu=$AndroidCpu"
    }
    $ninjaTargets = @('flutter/build/archives:archive_win_gen_snapshot')
}
if ($NinjaTarget.Count -gt 0) {
    $ninjaTargets = $NinjaTarget
}

$gnCommand = if ($env:TITAN_GN) { $env:TITAN_GN } else { 'gn' }
$ninjaCommand = if ($env:TITAN_NINJA) { $env:TITAN_NINJA } else { 'ninja' }
$loadValue = if ($Load -gt 0) { $Load } else { $Jobs }
& $gnCommand @gnArguments
if ($LASTEXITCODE -ne 0) {
    throw "GN failed with exit code $LASTEXITCODE"
}
& $ninjaCommand '-C' (Join-Path $engineRoot "out/$OutName") '-j' $Jobs '-l' $loadValue @ninjaTargets
if ($LASTEXITCODE -ne 0) {
    throw "Ninja failed with exit code $LASTEXITCODE"
}
Write-Output "Windows engine targets complete: $OutName"
