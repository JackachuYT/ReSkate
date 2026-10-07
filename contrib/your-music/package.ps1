param(
    [Parameter(Mandatory)] [string] $Build,
    [Parameter(Mandatory)] [string] $Packer,
    [Parameter(Mandatory)] [string] $Out
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$kit = Join-Path $PSScriptRoot 'package'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) 'your-music-package'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage, (Join-Path $stage 'licenses') | Out-Null

Copy-Item (Join-Path $Build 'ReSkate.dll'), (Join-Path $Build 'ReSkateLauncher.exe') $stage
$scripts = 'Install Your Music.bat', 'install-your-music.ps1'
Get-ChildItem $kit -File | Where-Object { $scripts -notcontains $_.Name } | Copy-Item -Destination $stage

$modKit = Join-Path $stage 'YourMusic'
if (Test-Path (Join-Path $kit 'song')) {
    New-Item -ItemType Directory -Path $modKit | Out-Null
    Get-ChildItem $kit -Directory | Copy-Item -Destination $modKit -Recurse
    Copy-Item $Packer (Join-Path $modKit 'packer') -Recurse
    $scripts | ForEach-Object { Copy-Item (Join-Path $kit $_) $modKit }
}

Copy-Item (Join-Path $root 'LICENSE') (Join-Path $stage 'licenses\ReSkate-LICENSE.txt')
Get-ChildItem (Join-Path $root 'External') -Recurse -File -Include '*LICENSE*', '*COPYING*' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $stage ('licenses\' + $_.Directory.Name + '-' + $_.Name))
}
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $Out -Force
Write-Host "Packaged $Out"
