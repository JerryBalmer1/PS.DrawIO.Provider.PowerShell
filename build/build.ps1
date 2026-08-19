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
    Invoke-Pester (Join-Path $root 'tests') -CI
    if ($LASTEXITCODE -ne 0) { throw 'Pester tests failed.' }
}
if ($Task -in 'All', 'Package') {
    Test-ModuleManifest $manifestPath | Out-Null
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
    Copy-Item (Join-Path $root 'src/*') $packagePath -Recurse -Force
    Write-Output "Packaged module at $packagePath"
}
