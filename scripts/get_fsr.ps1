# Downloads AMD's signed FSR 3.1 runtime (amd_fidelityfx_vk.dll, FidelityFX SDK v1.1.4) into
# third_party\ffx-api\bin, where the build picks it up. The DLL isn't kept in git.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root 'third_party\ffx-api\bin'
$dst  = Join-Path $dir 'amd_fidelityfx_vk.dll'
$url  = 'https://github.com/GPUOpen-LibrariesAndSDKs/FidelityFX-SDK/raw/v1.1.4/PrebuiltSignedDLL/amd_fidelityfx_vk.dll'

New-Item -ItemType Directory -Force $dir | Out-Null
Write-Host "Downloading $url"
Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
$size = (Get-Item $dst).Length
$sig  = Get-AuthenticodeSignature $dst
if ($size -lt 1MB -or $sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Advanced Micro Devices') {
    Remove-Item $dst
    throw "The download isn't AMD's signed DLL (size $size, signature $($sig.Status)). Get it by hand from the " +
          "FidelityFX SDK v1.1.4 release (PrebuiltSignedDLL folder) and put it in $dir"
}
Write-Host "OK: $dst ($([math]::Round($size / 1MB, 1)) MB, signed by AMD)" -ForegroundColor Green
