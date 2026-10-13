# TF3-DLSS: registers (install) or removes (uninstall) the Vulkan layer for the current Windows user.
# Called by install.bat / uninstall.bat. Writes only one registry value:
#   HKCU\SOFTWARE\Khronos\Vulkan\ImplicitLayers  "<this folder>\VkLayer_tf3_dlss_implicit.json" = 0
# The Vulkan loader then offers the layer to every Vulkan program, and the layer switches itself
# off in everything except TransportFever3.exe.
param([ValidateSet('install', 'uninstall', 'status')][string]$Action = 'status')
$ErrorActionPreference = 'Stop'
$subKey   = 'SOFTWARE\Khronos\Vulkan\ImplicitLayers'
$manifest = Join-Path $PSScriptRoot 'VkLayer_tf3_dlss_implicit.json'

function Open-LayersKey {
    # CreateSubKey opens the key if it exists (it never clears other layers' entries)
    [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($subKey)
}
function Get-OurEntries($key) {
    @($key.GetValueNames() | Where-Object { $_ -like '*VkLayer_tf3_dlss*' })
}

$key = Open-LayersKey
try {
    switch ($Action) {
        'install' {
            foreach ($f in 'VkLayer_tf3_dlss.dll', 'VkLayer_tf3_dlss_implicit.json') {
                if (-not (Test-Path (Join-Path $PSScriptRoot $f))) { throw "$f is missing from $PSScriptRoot" }
            }
            foreach ($old in Get-OurEntries $key) {
                if ($old -ne $manifest) {
                    $key.DeleteValue($old)
                    Write-Host "Removed an older registration: $old"
                }
            }
            $key.SetValue($manifest, 0, [Microsoft.Win32.RegistryValueKind]::DWord)
            Write-Host ''
            Write-Host 'TF3-DLSS is installed.' -ForegroundColor Green
            Write-Host "  Layer: $manifest"
            Write-Host ''
            Write-Host 'Start Transport Fever 3 as usual (from Steam), and set the game''s'
            Write-Host 'Resolution scale below 100% in its graphics options.'
            Write-Host 'Do not move or rename this folder: run uninstall.bat first, then install.bat again.'
        }
        'uninstall' {
            $entries = Get-OurEntries $key
            foreach ($old in $entries) { $key.DeleteValue($old); Write-Host "Removed: $old" }
            Write-Host ''
            if ($entries.Count) { Write-Host 'TF3-DLSS is uninstalled. You can delete this folder now.' -ForegroundColor Green }
            else { Write-Host 'TF3-DLSS was not installed for this Windows user.' }
        }
        'status' {
            $entries = Get-OurEntries $key
            if ($entries.Count) { $entries | ForEach-Object { Write-Host "Installed: $_" } }
            else { Write-Host 'Not installed.' }
        }
    }
} finally {
    $key.Close()
}
