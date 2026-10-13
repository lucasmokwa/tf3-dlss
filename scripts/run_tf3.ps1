# Starts Transport Fever 3 with VK_LAYER_TF3_dlss enabled for this launch only.
# Steam must be running. Nothing is installed system-wide: the layer is only active
# when the game is started from this script.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root 'build\bin'
$game = 'C:\Program Files (x86)\Steam\steamapps\common\Transport Fever 3'
$logs = Join-Path $root 'logs'

if (-not (Test-Path (Join-Path $bin 'VkLayer_tf3_dlss.dll'))) { throw "Layer not built yet - run build.ps1 first" }
New-Item -ItemType Directory -Force $logs | Out-Null

$env:VK_ADD_LAYER_PATH       = $bin                  # where the loader finds our manifest
$env:VK_INSTANCE_LAYERS      = 'VK_LAYER_TF3_dlss'   # enable it (older loader variable)
$env:VK_LOADER_LAYERS_ENABLE = 'VK_LAYER_TF3_dlss'   # enable it (newer loader variable)
$env:TF3_DLSS_LOG            = Join-Path $logs 'layer.log'
$env:TF3_DLSS_CFG            = Join-Path $root 'tf3_dlss.cfg'   # settings, editable while playing

Start-Process -FilePath (Join-Path $game 'TransportFever3.exe') -WorkingDirectory $game
Write-Host "Started TF3 with the layer. Log: $env:TF3_DLSS_LOG" -ForegroundColor Green
