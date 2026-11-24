#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ComputerName,
    [string]$InstallerPath = '\\vfs01\soft\Programs\crypto pro\CryptoPro-5.0.13820.exe',
    [switch]$Repair,
    [switch]$Clean,
    [switch]$Restart
)
$ErrorActionPreference = 'Stop'
if ($Repair -and $Clean) { throw "Choose Repair or Clean, not both." }
$Session = New-PSSession -ComputerName $ComputerName
try {
    $Folder = Invoke-Command -Session $Session -ScriptBlock {
        $Path = Join-Path $env:ProgramData ('CryptoProDeployment\Remote-' + [guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        $Path
    }
    $Bundled = Join-Path $PSScriptRoot 'Installers\CryptoPro-5.0.13820.exe'
    if (-not $PSBoundParameters.ContainsKey('InstallerPath') -and (Test-Path -LiteralPath $Bundled)) { $InstallerPath = $Bundled }
    Copy-Item -LiteralPath $InstallerPath -Destination "$Folder\CryptoPro-5.0.13820.exe" -ToSession $Session
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-CryptoPro.ps1') -Destination $Folder -ToSession $Session
    if ($Clean) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Clean-Reinstall-CryptoPro.ps1') -Destination $Folder -ToSession $Session }
    $Result = Invoke-Command -Session $Session -ArgumentList $Folder,([bool]$Repair),([bool]$Clean) -ScriptBlock {
        param($Folder,$Repair,$Clean)
        $ArgsList = @('-NoProfile','-NonInteractive','-File',"$Folder\Install-CryptoPro.ps1",'-InstallerPath',"$Folder\CryptoPro-5.0.13820.exe")
        if ($Repair) { $ArgsList += '-Repair' }
        if ($Clean) { $ArgsList[4] = "$Folder\Clean-Reinstall-CryptoPro.ps1"; $ArgsList += '-Force' }
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" @ArgsList | Out-Host
        $LASTEXITCODE
    }
    Write-Host "Remote exit code: $Result"
    if ($Clean -and $Result -eq 3010) { Write-Warning "Reboot required; run normal deployment afterward to ensure installation is complete." }
    if ($Result -notin @(0,3010,1641)) { throw "Deployment failed: $Result" }
} finally { Remove-PSSession $Session }
if ($Restart -and $Result -ne 1641) { Restart-Computer -ComputerName $ComputerName -Wait -For PowerShell -Timeout 300 }
exit $Result
