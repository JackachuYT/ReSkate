# Builds the Your Music companion mod (one silent song and the "Your Music" playlist) into
# Mods\YourMusic beside Skate.exe. ReSkateMusicPacker needs this PC's game files, so this
# runs here rather than on our build server.
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$game = Split-Path $kit -Parent
$packer = Join-Path $kit 'packer\ReSkateMusicPacker.exe'
$ffmpeg = Join-Path $kit 'ffmpeg'

function Invoke-Packer([string[]] $Arguments) {
    # The packer is a windowed app; Start-Process -Wait keeps its console output here and waits for it.
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $packer -ArgumentList ($quoted -join ' ') -Wait -NoNewWindow -PassThru
    return $process.ExitCode
}

try {
    if (-not (Test-Path (Join-Path $game 'Skate.exe'))) {
        throw "Put the YourMusic folder inside your skate. folder (the one with Skate.exe), then run this again."
    }
    if (Get-Process -Name 'Skate' -ErrorAction SilentlyContinue) {
        throw "Close skate. first, then run this again."
    }
    Write-Host 'Step 1 of 2: getting ffmpeg (only needed the first time, about 100 MB)...'
    if (-not (Test-Path (Join-Path $ffmpeg 'ffmpeg.exe'))) {
        if ((Invoke-Packer @('--get-ffmpeg', $ffmpeg)) -ne 0) { throw 'Could not download ffmpeg.' }
    }
    $env:PATH = $ffmpeg + ';' + $env:PATH

    Write-Host 'Step 2 of 2: building the Your Music mod...'
    $out = Join-Path $game 'Mods\YourMusic'
    $arguments = @($game, (Join-Path $kit 'song'), $out, '--name', 'YourMusic', '--playlist', 'Your Music',
                   '--no-normalize', '--bitrate', '64', '--generate-playlist-artwork', 'Your Music')
    if ((Invoke-Packer $arguments) -ne 0) { throw 'The music packer failed. The messages above say why.' }

    Write-Host ''
    Write-Host 'Done! Now open ReSkateLauncher, go to MODS, and make sure YourMusic is turned on.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
}
Read-Host 'Press Enter to close'
