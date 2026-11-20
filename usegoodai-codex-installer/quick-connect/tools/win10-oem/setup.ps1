$ErrorActionPreference = 'Stop'
$action = New-ScheduledTaskAction -Execute 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -Argument '-NoLogo -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\OEM\guest.ps1'
$trigger = New-ScheduledTaskTrigger -AtLogOn -User 'UseGoodAITest'
$principal = New-ScheduledTaskPrincipal -UserId 'UseGoodAITest' -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'UseGoodAI-ChineseUI' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
# OEM setup can finish either before or after the first interactive logon.
# Start now when that user already has a desktop; otherwise AtLogOn starts it.
try { Start-ScheduledTask -TaskName 'UseGoodAI-ChineseUI' -ErrorAction Stop } catch { }
