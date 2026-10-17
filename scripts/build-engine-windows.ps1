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

$depotToolsDirectory = Join-Path $WorkDir 'depot_tools'
$gclientPath = Join-Path $flutterDirectory '.gclient'
$patchStatePath = Join-Path $flutterDirectory '.titan-patches.windows.sha256'
$env:DEPOT_TOOLS_UPDATE = '0'
$env:DEPOT_TOOLS_METRICS = '0'
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$pythonCommand = if ($env:TITAN_PYTHON) { $env:TITAN_PYTHON } else { 'python' }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

function Invoke-Git {
    param([string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git failed with exit code $LASTEXITCODE"
    }
}

function Write-Gclient {
    param(
        [string]$Path,
        [string]$Target
    )

    $temporaryPath = "$Path.tmp"
    $generator = @'
import json
import re
import sys
from pathlib import Path

gclient_path = Path(sys.argv[1])
temporary_path = Path(sys.argv[2])
target = sys.argv[3]
target_custom_vars = {
    "windows": {
        "download_android_deps": True,
        "download_emsdk": False,
        "download_esbuild": True,
        "download_fuchsia_deps": False,
        "download_windows_deps": True,
        "setup_githooks": False,
    },
}

try:
    custom_vars = target_custom_vars[target]
except KeyError as error:
    print(f"unsupported gclient target: {target}", file=sys.stderr)
    sys.exit(2)

if gclient_path.exists():
    namespace = {}
    exec(gclient_path.read_text(encoding="utf-8"), {}, namespace)
    solutions = namespace.get("solutions")
    if not isinstance(solutions, list) or not solutions:
        print(f"invalid gclient solutions: {gclient_path}", file=sys.stderr)
        sys.exit(2)
else:
    solutions = [
        {
            "custom_deps": {},
            "deps_file": "DEPS",
            "managed": False,
            "name": ".",
            "safesync_url": "",
            "url": "https://github.com/flutter/flutter.git",
        }
    ]

solutions[0].setdefault("custom_vars", {}).update(custom_vars)
serialized_solutions = json.dumps(solutions, indent=2)
serialized_solutions = re.sub(r"\btrue\b", "True", serialized_solutions)
serialized_solutions = re.sub(r"\bfalse\b", "False", serialized_solutions)
serialized_solutions = re.sub(r"\bnull\b", "None", serialized_solutions)
serialized = ("solutions = " + serialized_solutions).encode("utf-8")
if gclient_path.exists() and gclient_path.read_bytes() == serialized:
    sys.exit(1)
temporary_path.write_bytes(serialized)
'@

    & $pythonCommand -c $generator $Path $temporaryPath $Target
    $status = $LASTEXITCODE
    if ($status -eq 2) {
        throw 'failed to generate .gclient'
    }
    if ($status -eq 1) {
        if (Test-Path $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
        return $false
    }
    if ($status -ne 0) {
        throw "gclient generation failed with exit code $status"
    }
    Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    return $true
}

function Get-PatchHash {
    $hashInput = [System.Text.StringBuilder]::new()
    [void]$hashInput.Append([System.IO.File]::ReadAllText($seriesFile))
    $folders = & $pythonCommand (Join-Path $repositoryRoot 'scripts/patch_series.py') --series $seriesFile --all
    if ($LASTEXITCODE -ne 0) {
        throw 'patch_series.py failed'
    }
    foreach ($folder in $folders) {
        $folderPath = Join-Path $patchRoot $folder
        $patches = Get-ChildItem -Path $folderPath -Filter '*.patch' -File | Sort-Object Name
        foreach ($patch in $patches) {
            [void]$hashInput.Append([System.IO.File]::ReadAllText($patch.FullName))
        }
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput.ToString())
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

if (-not (Test-Path $depotToolsDirectory)) {
    Invoke-Git @('clone', 'https://chromium.googlesource.com/chromium/tools/depot_tools.git', $depotToolsDirectory)
}
$env:PATH = "$depotToolsDirectory;$env:PATH"
$gclientCommand = Join-Path $depotToolsDirectory 'gclient.bat'
if (-not (Test-Path $gclientCommand)) {
    throw "gclient.bat is missing: $gclientCommand"
}

$bootstrap = $false
$flutterCheckoutNew = $false
if (-not (Test-Path (Join-Path $flutterDirectory '.git'))) {
    New-Item -ItemType Directory -Force -Path $flutterDirectory | Out-Null
    Invoke-Git @('init', $flutterDirectory)
    Invoke-Git @('-C', $flutterDirectory, 'remote', 'add', 'origin', 'https://github.com/flutter/flutter.git')
    $bootstrap = $true
    $flutterCheckoutNew = $true
}

$gclientChanged = Write-Gclient $gclientPath 'windows'
if ($bootstrap) {
    if ($flutterCheckoutNew) {
        Invoke-Git @('-C', $flutterDirectory, 'fetch', '--depth', '1', 'origin', $flutterCommit)
        Invoke-Git @('-C', $flutterDirectory, 'checkout', '--detach', 'FETCH_HEAD')
    } else {
        Invoke-Git @('-C', $flutterDirectory, 'fetch', 'origin', $flutterCommit)
        Invoke-Git @('-C', $flutterDirectory, 'checkout', '--detach', $flutterCommit)
    }
}
if ($bootstrap -or $gclientChanged) {
    Push-Location $flutterDirectory
    & $gclientCommand sync -D --no-history
    $gclientStatus = $LASTEXITCODE
    Pop-Location
    if ($gclientStatus -ne 0) {
        throw "gclient sync failed with exit code $gclientStatus"
    }
}

$actualCommit = (& git -C $flutterDirectory rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'cannot inspect the Flutter checkout'
}
if ($actualCommit -ne $flutterCommit) {
    $status = & git -C $flutterDirectory status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'cannot inspect the Flutter checkout'
    }
    if (-not [string]::IsNullOrWhiteSpace(($status -join ''))) {
        throw "Flutter checkout has local changes: $flutterDirectory"
    }
    Invoke-Git @('-C', $flutterDirectory, 'fetch', 'origin', $flutterCommit)
    Invoke-Git @('-C', $flutterDirectory, 'checkout', '--detach', $flutterCommit)
}
if (-not (Test-Path (Join-Path $engineRoot 'flutter'))) {
    throw "Flutter engine source is missing: $engineRoot"
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

$patchHash = Get-PatchHash
if (-not (Test-Path $patchStatePath) -or (Get-Content -Raw $patchStatePath) -ne $patchHash) {
    $status = & git -C $flutterDirectory status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'cannot inspect the Flutter checkout'
    }
    if (-not [string]::IsNullOrWhiteSpace(($status -join ''))) {
        throw "Flutter checkout has local changes: $flutterDirectory"
    }
    Apply-PatchSeries
    [System.IO.File]::WriteAllText($patchStatePath, $patchHash)
}

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
