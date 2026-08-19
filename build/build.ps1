[CmdletBinding()]
param(
    [ValidateSet('All', 'Clean', 'Analyze', 'Test', 'Package')]
    [string]$Task = 'All'
)

$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $root 'src/PS.DrawIO.Provider.PowerShell.psd1'
$packagePath = Join-Path $root 'dist/PS.DrawIO.Provider.PowerShell'

if ($Task -in 'All', 'Clean') {
    if (Test-Path $packagePath) { Remove-Item $packagePath -Recurse -Force }
}
if ($Task -in 'All', 'Analyze') {
    $analysis = @(Invoke-ScriptAnalyzer -Path (Join-Path $root 'src') -Recurse -Severity Error, Warning)
    if ($analysis.Count -gt 0) { $analysis | Format-List; throw 'ScriptAnalyzer reported errors or warnings.' }
}
if ($Task -in 'All', 'Test') {
        $isCI = [bool]$env:CI -or [bool]$env:TF_BUILD -or [bool]$env:GITHUB_ACTIONS
        $result = Invoke-Pester (Join-Path $root 'tests') -PassThru
        if ($result.FailedCount -gt 0) {
            if ($isCI) { exit 1 }
            throw "Pester: $($result.FailedCount) test(s) failed."
        }
        $ranNothing = @($result.Containers | Where-Object { $_.Tests.Count -eq 0 })
        if ($ranNothing) {
            if ($isCI) { exit 1 }
            throw "Pester: container produced no tests: $($ranNothing.Name -join ', ')"
        }
}
if ($Task -in 'All', 'Package') {
    Test-ModuleManifest $manifestPath | Out-Null
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
    Copy-Item (Join-Path $root 'src/*') $packagePath -Recurse -Force
    Write-Output "Packaged module at $packagePath"
}
