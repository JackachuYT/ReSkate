# Removes Your Music: the hidden updater, the playlist mod, and our ReSkate.dll (by turning the ReSkate
# launcher's own updates back on, so it puts the official ReSkate.dll back the next time it starts).
. (Join-Path $PSScriptRoot 'your-music-common.ps1')

try {
    if (Test-GameRunning) { throw 'Close skate. and the ReSkate launcher first, then run this again.' }
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log 'Automatic updates removed.'
    }
    if (Test-Path $ModDir) { Remove-Item $ModDir -Recurse -Force; Write-Log 'Removed Mods\YourMusic.' }
    Set-LauncherUpdates $true
    Write-Host ''
    Write-Host 'Your Music is uninstalled. Start ReSkateLauncher once: it puts the normal ReSkate.dll back.' -ForegroundColor Green
    Write-Host 'Then you can delete this YourMusic folder.'
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
}
Read-Host 'Press Enter to close'
