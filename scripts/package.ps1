# Builds the release folder and zip from build\bin and build\proxy. The zip's contents go straight
# into the game folder, next to TransportFever3.exe:
#   dist\release\version.dll           enables the layer for the game (build\proxy)
#   dist\release\TF3-DLSS\             README.txt, tf3_dlss.cfg, licenses\, bin\ (layer + runtimes)
#   dist\TF3-DLSS-<ver>.zip
# Run build.ps1 (Release) first. Upload the zip to the GitHub release; it's not kept in git.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bin  = Join-Path $root 'build\bin'
$pkg  = Join-Path $root 'package'
$dist = Join-Path $root 'dist'
$rel  = Join-Path $dist 'release'
$out  = Join-Path $rel 'TF3-DLSS'
$proxy = Join-Path $root 'build\proxy\version.dll'

$ver = (Select-String -Path (Join-Path $root 'layer\src\layer.cpp') -Pattern '#define TF3_DLSS_VERSION "(.+)"').Matches[0].Groups[1].Value
if (-not $ver) { throw 'TF3_DLSS_VERSION not found in layer.cpp' }

$need = 'VkLayer_tf3_dlss.dll', 'VkLayer_tf3_dlss.json', 'nvngx_dlss.dll', 'amd_fidelityfx_vk.dll'
foreach ($f in $need) { if (-not (Test-Path (Join-Path $bin $f))) { throw "build\bin\$f is missing (build.ps1, get_fsr.ps1)" } }
if (-not (Test-Path $proxy)) { throw 'build\proxy\version.dll is missing (build.ps1)' }

# The shipped cfg must have the developer options off.
$cfg = Get-Content (Join-Path $root 'tf3_dlss.cfg') -Raw
foreach ($pair in 'debug_keys=0', 'debug_view=0', 'dlss_dev=0', 'fsr_debug=0', 'enabled=1', 'upscaler=auto') {
    if ($cfg -notmatch "(?m)^$([regex]::Escape($pair))\s*$") { throw "tf3_dlss.cfg should have $pair for a release" }
}

if (Test-Path $rel) { Remove-Item $rel -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $out 'bin'), (Join-Path $out 'licenses') | Out-Null
foreach ($f in $need) { Copy-Item (Join-Path $bin $f) (Join-Path $out 'bin') }
Copy-Item $proxy $rel
Copy-Item (Join-Path $pkg 'licenses\*') (Join-Path $out 'licenses')
Copy-Item (Join-Path $pkg 'README.txt') $out
Copy-Item (Join-Path $root 'tf3_dlss.cfg') $out

$zip = Join-Path $dist "TF3-DLSS-$ver.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $rel '*') -DestinationPath $zip
Get-ChildItem $rel -Recurse -File | ForEach-Object { '{0,10:N0}  {1}' -f $_.Length, $_.FullName.Substring($rel.Length + 1) }
Write-Host "Packaged $zip" -ForegroundColor Green
