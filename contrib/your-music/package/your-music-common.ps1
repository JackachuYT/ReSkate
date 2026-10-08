# Shared by the Your Music installer, updater and uninstaller (dot-sourced). Windows PowerShell 5.1.
# Everything here works inside the skate. folder: $GameDir holds Skate.exe, $KitDir is its YourMusic folder.

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # Windows PowerShell 5.1's progress bar makes downloads crawl
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$KitDir = $PSScriptRoot
$GameDir = Split-Path $KitDir -Parent
$ModDir = Join-Path $GameDir 'Mods\YourMusic'
$LogFile = Join-Path $KitDir 'update.log'
$FfmpegDir = Join-Path $KitDir 'ffmpeg'
$PackerExe = Join-Path $KitDir 'packer\ReSkateMusicPacker.exe'
$LauncherExe = Join-Path $GameDir 'ReSkateLauncher.exe'
$LauncherSettings = Join-Path $GameDir 'ReSkateLauncher.settings.json'
$TaskName = 'Your Music for ReSkate updater'
$Repo = 'JackachuYT/ReSkate'

function Write-Log([string] $Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    try {
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 512KB) {
            Move-Item $LogFile "$LogFile.old" -Force
        }
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch {}
    Write-Host $Message
}

function Test-GameFolder {
    if (-not (Test-Path (Join-Path $GameDir 'Skate.exe'))) {
        throw "Put the YourMusic folder inside your skate. folder (the one with Skate.exe), then run this again."
    }
}

function Test-GameRunning {
    return [bool](Get-Process -Name 'Skate', 'ReSkateLauncher' -ErrorAction SilentlyContinue)
}

function Get-Sha256([string] $Path) {
    if (-not (Test-Path $Path)) { return '' }
    return (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

# The ReSkate launcher's own updater would put the official ReSkate.dll back over ours, so Your Music
# keeps it off and does ReSkate's updates itself. $true turns it back on (uninstall).
function Set-LauncherUpdates([bool] $Enabled) {
    $settings = New-Object PSObject
    if (Test-Path $LauncherSettings) {
        $text = Get-Content $LauncherSettings -Raw
        if ($text.Trim()) { $settings = $text | ConvertFrom-Json }
    }
    if ($settings.PSObject.Properties['updates'] -and $settings.updates -eq $Enabled) { return }
    $settings | Add-Member -NotePropertyName 'updates' -NotePropertyValue $Enabled -Force
    # No byte-order mark: Windows PowerShell 5.1's -Encoding UTF8 writes one, and the launcher reads plain JSON.
    [IO.File]::WriteAllText($LauncherSettings, ($settings | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding $false))
    Write-Log ("ReSkate launcher updates turned " + $(if ($Enabled) { 'on' } else { 'off' }) + '.')
}

function Invoke-Packer([string[]] $Arguments) {
    # The packer is a windowed app; Start-Process -Wait waits for it and keeps its output in this console.
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $PackerExe -ArgumentList ($quoted -join ' ') -Wait -NoNewWindow -PassThru
    return $process.ExitCode
}

# The Skate.exe build Mods\YourMusic was made for, from the packer's .reskate-studio-patch stamp.
function Get-ModGameSha256 {
    $stamp = Join-Path $ModDir '.reskate-studio-patch'
    if (-not (Test-Path $stamp)) { return '' }
    foreach ($line in Get-Content $stamp) {
        if ($line -match '^skate_sha256=([0-9a-fA-F]{64})$') { return $Matches[1].ToLowerInvariant() }
    }
    return ''
}

# Builds Mods\YourMusic (one silent song and the "Your Music" playlist) from this PC's game files.
function Build-YourMusicMod {
    if (-not (Test-Path (Join-Path $FfmpegDir 'ffmpeg.exe'))) {
        Write-Log 'Getting ffmpeg (first time only, about 100 MB)...'
        if ((Invoke-Packer @('--get-ffmpeg', $FfmpegDir)) -ne 0) { throw 'Could not download ffmpeg.' }
    }
    $env:PATH = $FfmpegDir + ';' + $env:PATH
    Write-Log 'Building the Your Music playlist mod...'
    $arguments = @($GameDir, (Join-Path $KitDir 'song'), $ModDir, '--name', 'YourMusic', '--playlist', 'Your Music',
                   '--no-normalize', '--bitrate', '64', '--generate-playlist-artwork', 'Your Music')
    if ((Invoke-Packer $arguments) -ne 0) { throw 'The music packer failed.' }
    Write-Log 'Your Music playlist mod built.'
}

function Get-InstalledVersion {
    $file = Join-Path $KitDir 'version.txt'
    if (-not (Test-Path $file)) { return '' }
    return (Get-Content $file -Raw).Trim()
}
