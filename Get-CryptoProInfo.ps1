#requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Get-CimInstance Win32_OperatingSystem | Select-Object CSName,LastBootUpTime
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'Crypto|Крипто|CAdES' } | Select-Object DisplayName,DisplayVersion,InstallDate,PSChildName
$Failed = $false
$Paths = @((Join-Path $env:ProgramFiles 'Crypto Pro\CSP\csptest.exe'))
if (${env:ProgramFiles(x86)}) { $Paths += Join-Path ${env:ProgramFiles(x86)} 'Crypto Pro\CSP\csptest.exe' }
foreach ($Path in ($Paths | Select-Object -Unique)) {
    Write-Host "=== $Path ==="
    if (-not (Test-Path -LiteralPath $Path)) { $Failed = $true; Write-Warning 'Missing'; continue }
    & $Path -enum -info
    if ($LASTEXITCODE -ne 0) { $Failed = $true }
}
$Pending = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
Write-Host "Pending file operations: $([bool]$Pending)"
Write-Host 'License: verify manually in cpanel.cpl (interactive desktop).'
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object TaskName -like '*КриптоПро CSP*' | Select-Object TaskName,State
if ($Failed) { exit 1 }
exit 0
