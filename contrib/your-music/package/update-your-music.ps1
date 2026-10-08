# Your Music's background updater. Windows Task Scheduler runs it every hour with no window and no
# prompts (Install Your Music.bat sets that up). It keeps three things current, and never touches
# anything while skate. or the ReSkate launcher is running:
#   - ReSkateLauncher.exe: the official launcher for the ReSkate version Your Music is built on
#   - ReSkate.dll and this YourMusic folder: the latest Your Music release
#   - Mods\YourMusic: rebuilt when the supported Skate.exe changes
# Every download is checked against the SHA-256 in the release's your-music.json first.
. (Join-Path $PSScriptRoot 'your-music-common.ps1')

function Get-ReleaseJson([string] $Url) {
    return Invoke-RestMethod -Uri $Url -UseBasicParsing -Headers @{ 'Accept' = 'application/vnd.github+json' }
}

function Save-Verified([string] $Url, [string] $Sha256, [long] $Size, [string] $Target) {
    $temporary = "$Target.download"
    Remove-Item $temporary -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $Url -OutFile $temporary -UseBasicParsing
    $actual = Get-Sha256 $temporary
    if ((Get-Item $temporary).Length -ne $Size -or $actual -ne $Sha256.ToLowerInvariant()) {
        Remove-Item $temporary -Force -ErrorAction SilentlyContinue
        throw "Download from $Url did not match its checksum."
    }
    return $temporary
}

function Update-Launcher($Manifest) {
    $launcher = $Manifest.launcher
    if ((Get-Sha256 $LauncherExe) -eq $launcher.sha256.ToLowerInvariant()) { return }
    Write-Log "Installing ReSkate launcher $($launcher.version)..."
    $file = Save-Verified $launcher.url $launcher.sha256 $launcher.size $LauncherExe
    Move-Item $file $LauncherExe -Force
    Write-Log "ReSkate launcher $($launcher.version) installed."
}

function Update-YourMusic($Manifest, $Release) {
    if ((Get-InstalledVersion) -eq $Manifest.version) { return }
    $asset = $Release.assets | Where-Object { $_.name -eq $Manifest.zip.name } | Select-Object -First 1
    if (-not $asset) { throw "The release has no $($Manifest.zip.name)." }
    Write-Log "Installing Your Music $($Manifest.version)..."
    $zip = Save-Verified $asset.browser_download_url $Manifest.zip.sha256 $Manifest.zip.size (Join-Path $env:TEMP 'ReSkate-YourMusic.zip')
    $unpacked = Join-Path $env:TEMP 'ReSkate-YourMusic'
    Remove-Item $unpacked -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive $zip -DestinationPath $unpacked -Force
    Remove-Item $zip -Force

    Copy-Item (Join-Path $unpacked 'ReSkate.dll') (Join-Path $GameDir 'ReSkate.dll') -Force
    Copy-Item (Join-Path $unpacked 'HOW TO INSTALL.txt') $GameDir -Force
    # The new kit replaces this one; the downloaded ffmpeg and the log stay. version.txt goes last,
    # so an update cut short is tried again next time. robocopy exit codes below 8 mean success.
    robocopy (Join-Path $unpacked 'YourMusic') $KitDir /E /XF version.txt /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Could not copy the new YourMusic files (robocopy $LASTEXITCODE)." }
    Copy-Item (Join-Path $unpacked 'YourMusic\version.txt') $KitDir -Force
    Remove-Item $unpacked -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Your Music $($Manifest.version) installed (ReSkate $($Manifest.reskate))."
}

function Update-Mod($Manifest) {
    $game = Get-Sha256 (Join-Path $GameDir 'Skate.exe')
    if ($game -ne $Manifest.game_sha256) {
        # Steam updated skate. past what ReSkate supports; the launcher puts the supported build back.
        Write-Log 'Skate.exe is not the build ReSkate supports yet; leaving the playlist mod alone.'
        return
    }
    if ((Test-Path $ModDir) -and (Get-ModGameSha256) -eq $game) { return }
    Build-YourMusicMod
}

try {
    Test-GameFolder
    if (Test-GameRunning) { Write-Log 'skate. or the ReSkate launcher is running; checking again later.'; exit 0 }
    $release = Get-ReleaseJson "https://api.github.com/repos/$Repo/releases/latest"
    $manifestAsset = $release.assets | Where-Object { $_.name -eq 'your-music.json' } | Select-Object -First 1
    if (-not $manifestAsset) { throw "The latest release ($($release.tag_name)) has no your-music.json." }
    # Release assets arrive as raw bytes, so read the file rather than trusting the response type.
    $manifestFile = Join-Path $env:TEMP 'your-music.json'
    Invoke-WebRequest -Uri $manifestAsset.browser_download_url -OutFile $manifestFile -UseBasicParsing
    $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
    Remove-Item $manifestFile -Force
    if ($manifest.schema -ne 1) { throw "your-music.json schema $($manifest.schema) needs a newer updater." }

    Set-LauncherUpdates $false
    Update-Launcher $manifest
    Update-YourMusic $manifest $release
    Update-Mod $manifest
    Write-Log "Up to date: Your Music $(Get-InstalledVersion), ReSkate $($manifest.reskate)."
} catch {
    Write-Log "Update check failed: $($_.Exception.Message)"
    exit 1
}
