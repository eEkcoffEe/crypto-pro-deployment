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
        $P = Start-Process -FilePath $Local -ArgumentList $Args -Wait -PassThru
        Write-Host "Installer exit code: $($P.ExitCode)"
        if ($P.ExitCode -notin @(0,3010,1641)) { throw "Installer failed: $($P.ExitCode)" }
        $After = @(Get-Products)
        if (-not @($After | Where-Object { $_.DisplayName -match ' CSP$' -and $_.DisplayVersion -eq "$Target" }).Count -or -not @($After | Where-Object { $_.DisplayName -match 'Browser plug-in$' -and $_.DisplayVersion -eq "$PluginTarget" }).Count) { throw 'Expected versions not detected after installation.' }
        $Code = $P.ExitCode
        Write-Host 'Installation completed. Verify CSP and license after a planned reboot.'
    }
} catch { Write-Host $_ -ForegroundColor Red; $Code = 1 }
finally {
    try { Stop-Transcript | Out-Null } catch {}
    if ($Locked) { $Mutex.ReleaseMutex() }
    $Mutex.Dispose()
}
if ($Restart -and $Code -in @(0,3010)) { Restart-Computer }
exit $Code
