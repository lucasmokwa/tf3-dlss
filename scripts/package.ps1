# Builds the release folder and zip from build\bin:
#   dist\TF3-DLSS\            README.txt, install.bat, uninstall.bat, tf3_dlss.cfg, licenses\, bin\
#   dist\TF3-DLSS-<ver>.zip
# Run build.ps1 (Release) first. Upload the zip to the GitHub release; it's not kept in git.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root 'build\bin'
$pkg  = Join-Path $root 'package'
$dist = Join-Path $root 'dist'
$out  = Join-Path $dist 'TF3-DLSS'

$ver = (Select-String -Path (Join-Path $root 'layer\src\layer.cpp') -Pattern '#define TF3_DLSS_VERSION "(.+)"').Matches[0].Groups[1].Value
if (-not $ver) { throw 'TF3_DLSS_VERSION not found in layer.cpp' }

$need = 'VkLayer_tf3_dlss.dll', 'VkLayer_tf3_dlss_implicit.json', 'nvngx_dlss.dll', 'amd_fidelityfx_vk.dll'
foreach ($f in $need) { if (-not (Test-Path (Join-Path $bin $f))) { throw "build\bin\$f is missing (build.ps1, get_fsr.ps1)" } }

# The shipped cfg must have the developer options off.
$cfg = Get-Content (Join-Path $root 'tf3_dlss.cfg') -Raw
foreach ($pair in 'debug_keys=0', 'debug_view=0', 'dlss_dev=0', 'fsr_debug=0', 'enabled=1', 'upscaler=auto') {
    if ($cfg -notmatch "(?m)^$([regex]::Escape($pair))\s*$") { throw "tf3_dlss.cfg should have $pair for a release" }
}

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $out 'bin'), (Join-Path $out 'licenses') | Out-Null
foreach ($f in $need) { Copy-Item (Join-Path $bin $f) (Join-Path $out 'bin') }
Copy-Item (Join-Path $pkg 'bin\tf3_dlss_setup.ps1') (Join-Path $out 'bin')
Copy-Item (Join-Path $pkg 'licenses\*') (Join-Path $out 'licenses')
Copy-Item (Join-Path $pkg 'README.txt'), (Join-Path $pkg 'install.bat'), (Join-Path $pkg 'uninstall.bat') $out
Copy-Item (Join-Path $root 'tf3_dlss.cfg') $out

$zip = Join-Path $dist "TF3-DLSS-$ver.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path $out -DestinationPath $zip
Get-ChildItem $out -Recurse -File | ForEach-Object { '{0,10:N0}  {1}' -f $_.Length, $_.FullName.Substring($out.Length + 1) }
Write-Host "Packaged $zip" -ForegroundColor Green
