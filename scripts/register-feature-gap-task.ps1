# Run this once, in an ELEVATED PowerShell window (Run as Administrator).
# Registers the daily feature-gap review to run once a day.
# The wrapper script checks that Pieces OS is running and exits immediately if not.
#
# Assumes feature-gap-wrapper.ps1 has been copied to your own $env:USERPROFILE\.claude\
# directory (Task Scheduler needs a stable, non-repo path to invoke).

$wrapperPath = Join-Path $env:USERPROFILE ".claude\feature-gap-wrapper.ps1"
$argumentString = '-ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $wrapperPath + '"'

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argumentString
$trigger = New-ScheduledTaskTrigger -Daily -At "3:17AM"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName "ToolRegistryFeatureGap" -Action $action -Trigger $trigger -Settings $settings -Description "Once daily, researches one tool_registry.md entry for underutilized features. Exits immediately if Pieces OS isn't running." -Force

Write-Output "Task registered. It will run daily at 3:17 AM (or at next logon if the machine was off, via StartWhenAvailable)."
Write-Output 'To remove it later, run: Unregister-ScheduledTask -TaskName "ToolRegistryFeatureGap" -Confirm:$false'
