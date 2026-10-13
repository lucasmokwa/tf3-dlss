# Starts TF3 with the layer AND the Khronos validation layer (Vulkan SDK), to catch API misuse.
# Slow; for testing only. Validation messages go to logs\validation.log.
#   .\run_validation.ps1          core validation
#   .\run_validation.ps1 -Sync    also synchronisation validation (much slower; finds missing barriers)
# Uses the development build (build\bin) like run_tf3.ps1. If the mod is also installed with
# install.bat, both registrations name the same layer and the loader uses one of them.
param([switch]$Sync)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root 'build\bin'
$game = 'C:\Program Files (x86)\Steam\steamapps\common\Transport Fever 3'
$logs = Join-Path $root 'logs'
if (-not $env:VULKAN_SDK) { throw 'VULKAN_SDK is not set (install the Vulkan SDK)' }
New-Item -ItemType Directory -Force $logs | Out-Null

$sdkLayers = Join-Path $env:VULKAN_SDK 'Bin'
$env:VK_ADD_LAYER_PATH       = "$bin;$sdkLayers"
# Our layer first = closest to the game, validation below it (closer to the driver): validation then
# sees the game's calls as we change them plus everything we record ourselves.
$env:VK_INSTANCE_LAYERS      = 'VK_LAYER_TF3_dlss;VK_LAYER_KHRONOS_validation'
$env:VK_LOADER_LAYERS_ENABLE = 'VK_LAYER_TF3_dlss,VK_LAYER_KHRONOS_validation'
if ($Sync) { $env:VK_LAYER_ENABLES = 'VK_VALIDATION_FEATURE_ENABLE_SYNCHRONIZATION_VALIDATION_EXT' }
else { Remove-Item Env:VK_LAYER_ENABLES -ErrorAction SilentlyContinue }
$env:VK_LAYER_REPORT_FLAGS   = 'error,warn'
$env:VK_LAYER_LOG_FILENAME   = Join-Path $logs 'validation.log'
$env:VK_LAYER_DEBUG_ACTION   = 'VK_DBG_LAYER_ACTION_LOG_MSG'
$env:TF3_DLSS_LOG            = Join-Path $logs 'layer.log'
$env:TF3_DLSS_CFG            = Join-Path $root 'tf3_dlss.cfg'

Start-Process -FilePath (Join-Path $game 'TransportFever3.exe') -WorkingDirectory $game
Write-Host "Started TF3 with validation. Messages: $env:VK_LAYER_LOG_FILENAME" -ForegroundColor Green
Write-Host 'Play a minute (move the camera, let vehicles drive), quit, then send me logs\validation.log.'
