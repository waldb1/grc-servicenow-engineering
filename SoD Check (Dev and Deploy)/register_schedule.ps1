$RunnerScriptPath = Join-Path $PSScriptRoot "automated_batch_job.ps1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$RunnerScriptPath`""

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8am

Register-ScheduledTask -TaskName "SoD Weekly Check" `
    -Action $action -Trigger $trigger `
    -Description "Weekly Segregation of Duties conflict check against ServiceNow"