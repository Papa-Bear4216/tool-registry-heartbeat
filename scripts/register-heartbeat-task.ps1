# Run this once, in an ELEVATED PowerShell window (Run as Administrator).
# Registers the tool-registry heartbeat to run at logon and every 45 minutes thereafter.
# The wrapper script itself checks that Pieces OS is running and exits immediately if not.

param(
    [string]$ScriptDir = $PSScriptRoot
)

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptDir\heartbeat-wrapper.ps1`""
$trigger1 = New-ScheduledTaskTrigger -AtLogOn
$trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 45) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName "ToolRegistryHeartbeat" `
    -Action $action `
    -Trigger @($trigger1, $trigger2) `
    -Settings $settings `
    -Description "Checks Pieces activity against tool_registry.md and notifies of relevant tool suggestions. Exits immediately if Pieces OS isn't running." `
    -Force

Write-Output "Task registered. It will run at next logon and every 45 minutes thereafter."
Write-Output "To remove it later: Unregister-ScheduledTask -TaskName 'ToolRegistryHeartbeat' -Confirm:`$false"
