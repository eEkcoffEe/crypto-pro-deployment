#requires -Version 5.1
#requires -RunAsAdministrator
[CmdletBinding()]
param([string]$InstallerPath, [switch]$Restart)
# Vendor-supported in-place reinstall; no key/container cleanup.
$Params = @{ Repair = $true; Restart = $Restart }
if ($InstallerPath) { $Params.InstallerPath = $InstallerPath }
& (Join-Path $PSScriptRoot 'Install-CryptoPro.ps1') @Params
exit $LASTEXITCODE
