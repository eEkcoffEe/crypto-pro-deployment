#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallerPath = '\\vfs01\soft\Programs\crypto pro\CryptoPro-5.0.13820.exe',
    [switch]$Force, [switch]$Restart
)
$ErrorActionPreference = 'Stop'
if (-not $Force) { throw 'Explicit -Force required. Back up keys and certificates before proceeding.' }
if (-not [Environment]::Is64BitProcess) { throw 'Use x64 PowerShell.' }
$Root = Join-Path $env:ProgramData 'CryptoProDeployment'
$Logs = Join-Path $Root 'Logs'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$Backup = Join-Path $Root "Backup-$Stamp"
$Code = 1
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
    # Use only MSI-managed removal. No manual vendor registry or key deletion.
    $NeedsRestart = $false
    foreach ($Product in ($Products | Sort-Object @{Expression={if ($_.DisplayName -match 'Browser plug-in$') {0} else {1}}})) {
        $Log = Join-Path $Logs "$Stamp-remove-$($Product.PSChildName).log"
        $Process = Start-Process msiexec.exe -ArgumentList "/x $($Product.PSChildName) /qn /norestart /L*v `"$Log`"" -Wait -PassThru
        if ($Process.ExitCode -eq 3010) { $NeedsRestart = $true }
        elseif ($Process.ExitCode -eq 1641) { $Code = 1641; break }
        elseif ($Process.ExitCode -notin @(0,1605)) { throw "Uninstall failed: $($Process.ExitCode)" }
    }
    if ($Code -ne 1641) {
        if ($NeedsRestart) { $Code = 3010; Write-Warning 'Removal requires reboot. After reboot run Install-CryptoPro.ps1, not Clean again.' }
        else { $Code = 0 }
    }
} catch { Write-Host $_ -ForegroundColor Red; $Code = 1 }
finally {
    if ($Transcript) { Stop-Transcript | Out-Null }
    if ($Locked) { $Mutex.ReleaseMutex() }
    $Mutex.Dispose()
}
if ($Code -eq 0) {
    & (Join-Path $PSScriptRoot 'Install-CryptoPro.ps1') -InstallerPath $Local -Restart:$Restart
    exit $LASTEXITCODE
}
if ($Code -eq 3010 -and $Restart) { Restart-Computer }
exit $Code
