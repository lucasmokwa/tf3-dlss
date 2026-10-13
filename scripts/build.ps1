# Builds the layer into ..\build\bin (VkLayer_tf3_dlss.dll + .json).
#   -DlssSdk <folder>  NVIDIA DLSS SDK (default: %USERPROFILE%\Projects\DLSS, set in CMakeLists.txt)
param([string]$DlssSdk)
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$src    = Join-Path $root 'layer'
$build  = Join-Path $root 'build'
$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

if (-not (Test-Path $vcvars)) {
    # Any other Visual Studio with the C++ tools (the GitHub Actions runner has VS 2022)
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vs) { $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat' }
    }
}
if (-not (Test-Path $vcvars)) { throw "vcvars64.bat not found at $vcvars" }

$sdkArg = if ($DlssSdk) { "-DDLSS_SDK=`"$DlssSdk`"" } else { '' }
cmd /s /c "`"$vcvars`" >nul && cmake -S `"$src`" -B `"$build`" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo $sdkArg && cmake --build `"$build`""
if ($LASTEXITCODE -ne 0) { throw "Build failed (exit $LASTEXITCODE)" }

Write-Host "Built: $build\bin\VkLayer_tf3_dlss.dll" -ForegroundColor Green
