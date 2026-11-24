#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallerPath = '\\vfs01\soft\Programs\crypto pro\CryptoPro-5.0.13820.exe',
    [switch]$Repair,
    [switch]$Restart
)
$ErrorActionPreference = 'Stop'
$Target = [version]'5.0.13820'
$PluginTarget = [version]'2.0.15820'
$Root = Join-Path $env:ProgramData 'CryptoProDeployment'
$Logs = Join-Path $Root 'Logs'
New-Item -ItemType Directory -Path $Logs -Force | Out-Null
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
function Get-Products {
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^(КриптоПро CSP|CryptoPro CSP|Crypto-Pro CSP|КриптоПро ЭЦП Browser plug-in|CryptoPro.*Browser plug-in)$' }
}
$Code = 1
$Mutex = New-Object System.Threading.Mutex($false,'Global\CryptoProDeployment')
$Locked = $false
try {
    $Locked = $Mutex.WaitOne(0)
    if (-not $Locked) { throw 'Another deployment is running.' }
    Start-Transcript -Path (Join-Path $Logs "$Stamp-install.txt") | Out-Null
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) { throw 'Use 64-bit Windows PowerShell.' }
    $Products = @(Get-Products)
    $Csp = @($Products | Where-Object DisplayName -match ' CSP$')
    $Plugin = @($Products | Where-Object DisplayName -match 'Browser plug-in$')
    $Products | Select-Object DisplayName,DisplayVersion,PSChildName | Format-Table | Out-Host
    if (@($Csp | Where-Object { [version]$_.DisplayVersion -gt $Target }).Count -or @($Plugin | Where-Object { [version]$_.DisplayVersion -gt $PluginTarget }).Count) { throw 'Newer component detected; downgrade blocked.' }
    if (-not $Repair -and @($Csp | Where-Object { [version]$_.DisplayVersion -eq $Target }).Count -and @($Plugin | Where-Object { [version]$_.DisplayVersion -eq $PluginTarget }).Count) {
        Write-Host 'Requested versions already installed.'
        $Code = 0
    } else {
        $Bundled = Join-Path $PSScriptRoot 'Installers\CryptoPro-5.0.13820.exe'
        if (-not $PSBoundParameters.ContainsKey('InstallerPath') -and (Test-Path -LiteralPath $Bundled)) { $InstallerPath = $Bundled }
        $Local = Join-Path $Root 'CryptoPro-5.0.13820.exe'
        if ((Resolve-Path -LiteralPath $InstallerPath).Path -ne $Local) { Copy-Item -LiteralPath $InstallerPath -Destination $Local -Force }
        $Sig = Get-AuthenticodeSignature -FilePath $Local
        if ($Sig.Status -ne 'Valid' -or $Sig.SignerCertificate.Subject -notmatch 'Crypto.?Pro|Крипто.?Про') { throw 'Installer signature or publisher check failed.' }
        Get-FileHash -LiteralPath $Local -Algorithm SHA256 | Format-List | Out-Host
        $CspLog = Join-Path $Logs "$Stamp-csp.log"
        $PluginLog = Join-Path $Logs "$Stamp-plugin.log"
        $Args = '-gm2 -silent -norestart -noyandex -lang rus -kc kc1'
        if ($Repair) { $Args += ' -reinstall' }
        $Args += ' -args "/qn /norestart /L*v ' + $CspLog + '" -cadesargs "/qn /norestart /L*v ' + $PluginLog + '"'
        function Wait-InstallReady {
            $Clock = [System.Diagnostics.Stopwatch]::StartNew()
            $FreeSince = $null
            do {
                $Reasons = @()
                try {
                    $MsiMutex = [System.Threading.Mutex]::OpenExisting('Global\_MSIExecute')
                    try {
                        try { $Acquired = $MsiMutex.WaitOne(0) }
                        catch [System.Threading.AbandonedMutexException] { $Acquired = $true }
                        if ($Acquired) { $MsiMutex.ReleaseMutex() } else { $Reasons += 'MSI execution mutex busy' }
                    } finally { $MsiMutex.Dispose() }
                } catch [System.Threading.WaitHandleCannotBeOpenedException] {} catch { $Reasons += "MSI mutex check failed: $_" }
                foreach ($Name in @('RpcSs','DcomLaunch','RpcEptMapper','gpsvc')) {
                    if ((Get-Service -Name $Name).Status -ne 'Running') { $Reasons += "Service $Name not running" }
                }
                $Processes = @(Get-CimInstance Win32_Process)
                foreach ($Proc in $Processes) {
                    if ($Proc.Name -match '^(CryptoPro.*\.exe|cspclean\.exe|gpupdate\.exe|setup\.exe)$' -or
                        ($Proc.Name -eq 'msiexec.exe' -and $Proc.CommandLine -match '(?i)(?:^|\s)[/-](?:i|x|package|uninstall|update|p|f\w*)(?:\s|\{|"|$)')) {
                        $Reasons += "Process $($Proc.Name) PID $($Proc.ProcessId)"
                    }
                }
                if ($Reasons.Count) {
                    $FreeSince = $null
                    Write-Host "$(Get-Date -Format o) Waiting: $($Reasons -join '; ')"
                } else {
                    if ($null -eq $FreeSince) { $FreeSince = $Clock.Elapsed.TotalSeconds }
                    if (($Clock.Elapsed.TotalSeconds - $FreeSince) -ge 15) {
                        Write-Host "$(Get-Date -Format o) Readiness checks clear for 15 seconds."
                        return
                    }
                }
                Start-Sleep -Seconds 5
            } while ($Clock.Elapsed.TotalSeconds -lt 900)
            throw 'Readiness timeout (15 minutes). No installer launched.'
        }
        for ($Attempt = 1; $Attempt -le 3; $Attempt++) {
            Wait-InstallReady
            Write-Host "$(Get-Date -Format o) Launching installer: $Local (attempt $Attempt)"
            $P = Start-Process -FilePath $Local -ArgumentList $Args -PassThru
            Write-Host "$(Get-Date -Format o) Installer PID: $($P.Id)"
            if (-not $P.WaitForExit(900000)) {
                throw "Installer timeout (15 minutes), PID $($P.Id). Inspect processes and logs before retrying; installer was not terminated."
            }
            $P.Refresh()
            Write-Host "Installer exit code: $($P.ExitCode)"
            if ($P.ExitCode -ne 1618 -or $Attempt -eq 3) { break }
            Write-Host 'MSI conflict (1618); repeating readiness checks.'
        }
        if ($P.ExitCode -notin @(0,3010,1641)) { throw "Installer failed: $($P.ExitCode)" }
        $After = @(Get-Products)
        if (-not @($After | Where-Object { $_.DisplayName -match ' CSP$' -and $_.DisplayVersion -eq "$Target" }).Count -or -not @($After | Where-Object { $_.DisplayName -match 'Browser plug-in$' -and $_.DisplayVersion -eq "$PluginTarget" }).Count) { throw 'Expected versions not detected after installation.' }
        $Code = $P.ExitCode
        Write-Host 'Installation completed. Verify CSP and license after a planned reboot.'
    }
} catch { Write-Host ($_ | Format-List * -Force | Out-String) -ForegroundColor Red; $Code = 1 }
finally {
    try { Stop-Transcript | Out-Null } catch {}
    if ($Locked) { $Mutex.ReleaseMutex() }
    $Mutex.Dispose()
}
if ($Restart -and $Code -in @(0,3010)) { Restart-Computer -Force }
exit $Code
