# Tests the layer (build\bin, from build.ps1) without the game: builds and runs harness\fake_tf3, a small
# Vulkan program that renders frames shaped like TF3's and checks what the layer does with them (the
# upscaled image reaches the screen, motion vectors are exact, no validation errors). See harness\fake_tf3.cpp.
#   .\run_harness.ps1                 DLSS or FSR 3.1 as in the game (upscaler=auto), plus the CPU comparison
#   .\run_harness.ps1 -TestUpscaler   a plain resize instead of DLSS / FSR (as in CI)
#   .\run_harness.ps1 -Validation     also with the Khronos validation layer (Vulkan SDK) below ours
#   .\run_harness.ps1 -Threads 8      threads recording the scene (default 4)
# Output in logs\harness\<run>: fake_tf3.txt (results), tf3_dlss.log, last_frame.ppm, mvcap\.
param([switch]$TestUpscaler, [switch]$Validation, [int]$Threads = 4, [int]$Frames = 300)
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$bin    = Join-Path $root 'build\bin'
$build  = Join-Path $root 'build\harness'
$out    = Join-Path $root 'logs\harness'
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
if (-not (Test-Path $vcvars)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vs) { $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat' }
    }
}
if (-not (Test-Path (Join-Path $bin 'VkLayer_tf3_dlss.dll'))) { throw 'build\bin\VkLayer_tf3_dlss.dll not found: run build.ps1 first' }
$src = Join-Path $root 'harness'
cmd /s /c "`"$vcvars`" >nul && cmake -S `"$src`" -B `"$build`" -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build `"$build`""
if ($LASTEXITCODE -ne 0) { throw "Building fake_tf3 failed (exit $LASTEXITCODE)" }
$exe = Join-Path $build 'fake_tf3.exe'

$layers = 'VK_LAYER_TF3_dlss'
$layerPath = $bin
if ($Validation) {
    if (-not $env:VULKAN_SDK) { throw 'VULKAN_SDK is not set (install the Vulkan SDK)' }
    $layers = 'VK_LAYER_TF3_dlss;VK_LAYER_KHRONOS_validation'  # ours closest to the app, validation below
    $layerPath = "$bin;$(Join-Path $env:VULKAN_SDK 'Bin')"
}
$env:TF3_DLSS_FORCE   = '1'                 # the layer only acts in TransportFever3.exe otherwise
$env:TF3_DLSS_CAPTURE = '60,140,220'        # recordings the motion-vector checks read
if ($TestUpscaler) { $env:TF3_DLSS_TEST_UPSCALER = '1' } else { Remove-Item Env:TF3_DLSS_TEST_UPSCALER -ErrorAction SilentlyContinue }

$failed = $false
function Run([string]$name, [string]$cfg, [string]$withLayers, [string[]]$opts) {
    $dir = Join-Path $out $name
    if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
    New-Item -ItemType Directory -Force $dir | Out-Null
    $cfgFile = Join-Path $dir 'tf3_dlss.cfg'
    Copy-Item (Join-Path $root 'tf3_dlss.cfg') $cfgFile
    Add-Content $cfgFile "`n# test harness`n$cfg"
    $env:TF3_DLSS_CFG = $cfgFile
    $env:TF3_DLSS_LOG = Join-Path $dir 'tf3_dlss.log'
    if ($withLayers) {
        $env:VK_ADD_LAYER_PATH = $layerPath
        $env:VK_INSTANCE_LAYERS = $withLayers
        $env:VK_LOADER_LAYERS_ENABLE = $withLayers.Replace(';', ',')
    } else {
        Remove-Item Env:VK_ADD_LAYER_PATH, Env:VK_INSTANCE_LAYERS, Env:VK_LOADER_LAYERS_ENABLE -ErrorAction SilentlyContinue
    }
    Write-Host "== $name" -ForegroundColor Cyan
    & $exe --out $dir --frames $Frames --threads $Threads @opts 2>&1 | Tee-Object -FilePath (Join-Path $dir 'fake_tf3.txt')
    if ($LASTEXITCODE -ne 0) { $script:failed = $true }
    $log = Join-Path $dir 'tf3_dlss.log'
    if (Test-Path $log) { Select-String -Path $log -Pattern '^\[perf\]' | Select-Object -Last 4 | ForEach-Object { $_.Line } }
}

$vopt = @()
if ($Validation) { $vopt = @('--validation') }
Run 'checks' 'log_every=100' $layers $vopt
Run 'perf' "perf=1`nperf_seconds=5" 'VK_LAYER_TF3_dlss' @()
Run 'no_layer' '' '' @('--no-checks')
Write-Host ''
Write-Host 'CPU time per frame for recording, with and without the layer:'
Select-String -Path (Join-Path $out 'perf\fake_tf3.txt'), (Join-Path $out 'no_layer\fake_tf3.txt') -Pattern 'CPU time per frame' | ForEach-Object { $_.Line }
if ($failed) { Write-Host "harness: FAILED (details in $out)" -ForegroundColor Red; exit 1 }
Write-Host 'harness: all runs passed' -ForegroundColor Green
