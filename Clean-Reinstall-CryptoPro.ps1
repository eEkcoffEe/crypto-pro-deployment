#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallerPath = '\\vfs01\soft\Programs\crypto pro\CryptoPro-5.0.13820.exe',
    [string]$CleanerPath = (Join-Path $PSScriptRoot 'Installers\cspclean.exe'),
    [switch]$Force, [switch]$Restart, [switch]$KeysBackedUp
)
$ErrorActionPreference = 'Stop'
if (-not $KeysBackedUp) { throw 'Confirm verified external key backups with -KeysBackedUp.' }
if (-not $Force) { throw 'Explicit -Force required. Back up keys and certificates before proceeding.' }
if (-not [Environment]::Is64BitProcess) { throw 'Use x64 PowerShell.' }
$Root = Join-Path $env:ProgramData 'CryptoProDeployment'
$Logs = Join-Path $Root 'Logs'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$Backup = Join-Path $Root "Backup-$Stamp"
$Code = 1
$TaskName = 'CryptoProDeployment-Resume'
$Stage = Join-Path $Root "Resume-$Stamp"
$Mutex = New-Object System.Threading.Mutex($false,'Global\CryptoProDeployment')
$Locked = $false
$Transcript = $false
try {
    $Locked = $Mutex.WaitOne(0)
    if (-not $Locked) { throw 'Another deployment is running.' }
    New-Item -ItemType Directory -Path $Logs,$Backup -Force | Out-Null
    # Restrict access before writing registry backups.
    $Acl = Get-Acl $Backup
    $Acl.SetAccessRuleProtection($true,$false)
    foreach ($Sid in @('S-1-5-18','S-1-5-32-544')) {
        $Identity = New-Object System.Security.Principal.SecurityIdentifier($Sid)
        $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
        $Acl.AddAccessRule($Rule)
    }
    Set-Acl -Path $Backup -AclObject $Acl
    Start-Transcript -Path (Join-Path $Logs "$Stamp-clean.txt") | Out-Null
    $Transcript = $true
    $Bundled = Join-Path $PSScriptRoot 'Installers\CryptoPro-5.0.13820.exe'
    if (-not $PSBoundParameters.ContainsKey('InstallerPath') -and (Test-Path -LiteralPath $Bundled)) { $InstallerPath = $Bundled }
    $Cleaner = Get-Item -LiteralPath $CleanerPath
    $CleanerSig = Get-AuthenticodeSignature -FilePath $Cleaner.FullName
    if ($CleanerSig.Status -ne 'Valid' -or $CleanerSig.SignerCertificate.Subject -notmatch 'Crypto.?Pro|Крипто.?Про') { throw 'Cleaner signature or publisher check failed.' }
    $Other = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match 'КриптоПро|Crypto.?Pro|КриптоАРМ|CryptoARM' -and $_.DisplayName -notmatch '^(КриптоПро CSP|CryptoPro CSP|Crypto-Pro CSP|КриптоПро ЭЦП Browser plug-in|CryptoPro.*Browser plug-in)$' })
    if ($Other.Count) { throw ('Other crypto products detected: ' + ($Other.DisplayName -join ', ')) }
    $Local = Join-Path $Root 'CryptoPro-5.0.13820.exe'
    if ((Resolve-Path -LiteralPath $InstallerPath).Path -ne $Local) { Copy-Item -LiteralPath $InstallerPath -Destination $Local -Force }
    $Sig = Get-AuthenticodeSignature -FilePath $Local
    if ($Sig.Status -ne 'Valid' -or $Sig.SignerCertificate.Subject -notmatch 'Crypto.?Pro|Крипто.?Про') { throw 'Installer signature or publisher check failed.' }
    $Products = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^(КриптоПро CSP|CryptoPro CSP|Crypto-Pro CSP|КриптоПро ЭЦП Browser plug-in|CryptoPro.*Browser plug-in)$' })
    foreach ($Product in $Products) {
        $Max = if ($Product.DisplayName -match ' CSP$') { [version]'5.0.13820' } else { [version]'2.0.15820' }
        if ([version]$Product.DisplayVersion -gt $Max) { throw 'Downgrade blocked.' }
        if ($Product.PSChildName -notmatch '^\{[0-9A-Fa-f-]{36}\}$' -or $Product.WindowsInstaller -ne 1) { throw 'Unexpected uninstall entry.' }
    }
    $Products | Select-Object DisplayName,DisplayVersion,PSChildName | Export-Csv (Join-Path $Backup 'products.csv') -NoTypeInformation -Encoding UTF8
    foreach ($Key in @('HKLM\SOFTWARE\Crypto Pro','HKLM\SOFTWARE\WOW6432Node\Crypto Pro')) {
        if (Test-Path ($Key -replace '^HKLM\\','HKLM:\')) {
            $Name = ($Key -replace '[^a-zA-Z0-9]','_') + '.reg'
            & reg.exe export $Key (Join-Path $Backup $Name) /y | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'Registry backup failed.' }
        }
    }
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { throw 'A previous continuation task exists. Inspect its status before retrying.' }
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
    Set-Acl -Path $Stage -AclObject (Get-Acl $Backup)
    Copy-Item -LiteralPath $Local -Destination (Join-Path $Stage 'CryptoPro-5.0.13820.exe')
    Copy-Item -LiteralPath $Cleaner.FullName -Destination (Join-Path $Stage 'cspclean.exe')
    Unblock-File -LiteralPath (Join-Path $Stage 'cspclean.exe')
    foreach ($Name in @('Install-CryptoPro.ps1','Resume-CryptoPro.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $Name) -Destination $Stage
        Unblock-File -LiteralPath (Join-Path $Stage $Name)
    }
    if ($Restart) { New-Item -ItemType File -Path (Join-Path $Stage 'FinalRestart.flag') | Out-Null }
    # Use only MSI-managed removal. No manual vendor registry or key deletion.
    $NeedsRestart = $false
    foreach ($Product in ($Products | Sort-Object @{Expression={if ($_.DisplayName -match 'Browser plug-in$') {0} else {1}}})) {
        $Log = Join-Path $Logs "$Stamp-remove-$($Product.PSChildName).log"
        $Process = Start-Process msiexec.exe -ArgumentList "/x $($Product.PSChildName) /qn /norestart /L*v `"$Log`"" -Wait -PassThru
        if ($Process.ExitCode -eq 3010) { $NeedsRestart = $true }
        elseif ($Process.ExitCode -eq 1641) { throw 'Unexpected installer-initiated reboot (1641); inspect logs and install manually.' }
        elseif ($Process.ExitCode -notin @(0,1605)) { throw "Uninstall failed: $($Process.ExitCode)" }
    }
    $Action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -File "' + (Join-Path $Stage 'Resume-CryptoPro.ps1') + '"')
    $Trigger = New-ScheduledTaskTrigger -AtStartup
    $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Set-Content -LiteralPath (Join-Path $Stage 'phase.txt') -Value 'AwaitCleanup' -Encoding ASCII
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -ErrorAction Stop | Out-Null
    $Code = 3010
    Write-Warning 'Reboot required. After reboot run the cleanup command printed below in an elevated interactive PowerShell.'
    Write-Host ("& '" + (Join-Path $Stage 'Resume-CryptoPro.ps1') + "' -Cleanup")
} catch { Write-Host $_ -ForegroundColor Red; $Code = 1 }
finally {
    if ($Transcript) { Stop-Transcript | Out-Null }
    if ($Locked) { $Mutex.ReleaseMutex() }
    $Mutex.Dispose()
}
if ($Code -eq 3010 -and $Restart) { Restart-Computer }
exit $Code
