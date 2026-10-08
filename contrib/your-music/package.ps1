# Stages the release zip: only what Your Music adds to a working ReSkate install.
#   ReSkate.dll           ReSkate with Your Music built in (it replaces the player's ReSkate.dll)
#   HOW TO INSTALL.txt
#   YourMusic\            installer, updater, uninstaller, silent song, ReSkateMusicPacker, test checklist,
#                         licenses, version.txt (what the updater compares with the latest release)
param(
    [Parameter(Mandatory)] [string] $Version,
    [Parameter(Mandatory)] [string] $Build,
    [Parameter(Mandatory)] [string] $Packer,
    [Parameter(Mandatory)] [string] $Out
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$kit = Join-Path $PSScriptRoot 'package'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) 'your-music-package'
$modKit = Join-Path $stage 'YourMusic'
$licenses = Join-Path $modKit 'licenses'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage, $modKit, $licenses | Out-Null

Copy-Item (Join-Path $Build 'ReSkate.dll') $stage
Copy-Item (Join-Path $kit 'HOW TO INSTALL.txt') $stage
Get-ChildItem $kit -File | Where-Object { $_.Name -ne 'HOW TO INSTALL.txt' } | Copy-Item -Destination $modKit
Get-ChildItem $kit -Directory | Copy-Item -Destination $modKit -Recurse
Copy-Item $Packer (Join-Path $modKit 'packer') -Recurse
Set-Content (Join-Path $modKit 'version.txt') $Version -NoNewline

# ReSkate.dll is GPL-3.0 ReSkate plus Your Music, statically linked with the libraries in External/.
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $licenses 'ReSkate-LICENSE.txt')
Get-ChildItem (Join-Path $root 'External') -Recurse -File -Include '*LICENSE*', '*COPYING*' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $licenses ($_.Directory.Name + '-' + $_.Name))
}
Set-Content (Join-Path $licenses 'SOURCE.txt') @(
    'ReSkate.dll in this download is ReSkate (GPL-3.0, https://github.com/Dingo-Shenanigans/ReSkate)',
    'with Your Music added. Its complete source code is at https://github.com/JackachuYT/ReSkate'
)
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $Out -Force
Write-Host "Packaged $Out"
