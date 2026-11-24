#requires -Version 5.1
#requires -RunAsAdministrator
param([switch]$Cleanup)
$ErrorActionPreference = 'Stop'
$TaskName = 'CryptoProDeployment-Resume'
$Log = Join-Path $PSScriptRoot 'resume.log'
$PhaseFile = Join-Path $PSScriptRoot 'phase.txt'
$Phase = (Get-Content -LiteralPath $PhaseFile -Raw).Trim()
try {
    if ($Cleanup) {
        if ($Phase -ne 'AwaitCleanup') { throw 'Unexpected phase.' }
        $Exe = Join-Path $PSScriptRoot 'cspclean.exe'
        $Sig = Get-AuthenticodeSignature -FilePath $Exe
        if ($Sig.Status -ne 'Valid' -or $Sig.SignerCertificate.Subject -notmatch 'Crypto.?Pro|Крипто.?Про') { throw 'Cleaner signature check failed.' }
        Write-Warning 'Do not approve deletion of private keys. Close the cleaner if uncertain.'
        $P = Start-Process -FilePath $Exe -Wait -PassThru
        Add-Content $Log "Cleaner exit: $($P.ExitCode)"
        if ($P.ExitCode -notin @(0,3010)) { throw 'Cleanup failed; inspect manually.' }
        if ((Read-Host 'Confirm successful cleanup with keys preserved (YES)') -cne 'YES') { throw 'Cleanup not confirmed.' }
        Set-Content -LiteralPath $PhaseFile -Value 'Install' -Encoding ASCII
        Restart-Computer -Force
        exit 0
    }
    if ($Phase -eq 'AwaitCleanup') { Add-Content $Log 'Waiting for interactive cleanup.'; exit 0 }
    Disable-ScheduledTask -TaskName $TaskName | Out-Null
    if ($Phase -eq 'Install') {
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Install-CryptoPro.ps1') -InstallerPath (Join-Path $PSScriptRoot 'CryptoPro-5.0.13820.exe') *>> $Log
        $Code = $LASTEXITCODE
        if ($Code -notin @(0,3010)) { throw "Installation failed: $Code" }
        Set-Content -LiteralPath $PhaseFile -Value 'Verify' -Encoding ASCII
        Enable-ScheduledTask -TaskName $TaskName | Out-Null
        Restart-Computer -Force
        exit 0
    }
    if ($Phase -ne 'Verify') { throw 'Unexpected phase.' }
    foreach ($Exe in @("$env:ProgramFiles\Crypto Pro\CSP\csptest.exe", "${env:ProgramFiles(x86)}\Crypto Pro\CSP\csptest.exe")) {
        if (-not (Test-Path -LiteralPath $Exe)) { throw "Missing: $Exe" }
        & $Exe -enum -info *>> $Log
        if ($LASTEXITCODE -ne 0) { throw "CSP test failed: $Exe" }
    }
    Set-Content -LiteralPath $PhaseFile -Value 'Done' -Encoding ASCII
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Add-Content $Log 'Completed. Verify license manually.'
} catch { Add-Content $Log ($_ | Out-String); Write-Error $_; exit 1 }
