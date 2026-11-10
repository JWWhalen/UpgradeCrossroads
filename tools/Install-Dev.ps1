param([Parameter(Mandatory=$true)][string]$AddOnsPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceFolder = Join-Path $projectRoot 'UpgradeCrossroads'
if (-not (Test-Path (Join-Path $sourceFolder 'UpgradeCrossroads.toc'))) {
    throw 'Run this script from the full Upgrade Crossroads development package.'
}
$resolvedAddOns = (Resolve-Path -LiteralPath $AddOnsPath).Path
if ((Split-Path $resolvedAddOns -Leaf) -ne 'AddOns') {
    throw 'Choose the existing Interface\AddOns directory, not the WoW root or addon folder.'
}
$destinationFolder = Join-Path $resolvedAddOns 'UpgradeCrossroads'
if ([System.IO.Path]::GetFullPath($sourceFolder) -eq [System.IO.Path]::GetFullPath($destinationFolder)) {
    throw 'The source and installed copy are the same folder. Use C:\Dev\UpgradeCrossroads as your development folder.'
}
New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
Copy-Item -Path (Join-Path $sourceFolder '*') -Destination $destinationFolder -Recurse -Force
Write-Host "Installed the development copy to $destinationFolder"
Write-Host 'Start WoW, or /reload for Lua edits. Restart the client after TOC changes.'
