# Builds the layer into ..\build\bin (VkLayer_tf3_dlss.dll + .json).
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root 'layer'
$build  = Join-Path $root 'build'
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found at $vcvars" }

cmd /s /c "`"$vcvars`" >nul && cmake -S `"$src`" -B `"$build`" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo && cmake --build `"$build`""
if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)" }

Write-Host "Built: $build\bin\VkLayer_tf3_dlss.dll" -ForegroundColor Green
