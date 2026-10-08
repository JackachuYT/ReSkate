# One-time Your Music install. After this, Your Music keeps itself and ReSkate up to date in the
# background (update-your-music.ps1, run hourly by Windows Task Scheduler, no windows or prompts).
#   1. builds Mods\YourMusic (one silent song and the "Your Music" playlist) from this PC's game files
#   2. turns off the ReSkate launcher's own updater, which would put the official ReSkate.dll back
#   3. registers the hidden updater task and runs it once
. (Join-Path $PSScriptRoot 'your-music-common.ps1')

function Register-Updater {
    $updater = Join-Path $KitDir 'update-your-music.ps1'
    # conhost --headless runs PowerShell without opening a console window.
    $action = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument (
        '--headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $updater + '"')
    $triggers = @(New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 1))
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) -MultipleInstances IgnoreNew
    $description = 'Keeps Your Music for ReSkate and ReSkate up to date. Remove it with YourMusic\Uninstall Your Music.bat.'
    try {
        # Also at log on, where Windows allows that without administrator rights.
        Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -Settings $settings -Description $description `
            -Trigger ($triggers + (New-ScheduledTaskTrigger -AtLogOn -User $user)) -Force | Out-Null
    } catch {
        Register-ScheduledTask -TaskName $TaskName -Action $action -Principal $principal -Settings $settings -Description $description `
            -Trigger $triggers -Force | Out-Null
    }
    Write-Log 'Automatic updates set up (checks every hour in the background).'
}

try {
    Test-GameFolder
    if (Test-GameRunning) { throw 'Close skate. and the ReSkate launcher first, then run this again.' }
    Write-Host 'Step 1 of 3: building the Your Music playlist mod...'
    Build-YourMusicMod
    Write-Host 'Step 2 of 3: handing ReSkate updates over to Your Music...'
    Set-LauncherUpdates $false
    Write-Host 'Step 3 of 3: setting up automatic updates...'
    Register-Updater
    & (Join-Path $KitDir 'update-your-music.ps1')
    Write-Host ''
    Write-Host 'Done! Start ReSkateLauncher and press PLAY. From now on Your Music updates itself.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
}
Read-Host 'Press Enter to close'
