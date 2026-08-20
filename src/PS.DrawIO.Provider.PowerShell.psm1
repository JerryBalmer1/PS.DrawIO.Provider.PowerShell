$moduleRoot = Split-Path -Parent $PSCommandPath
# Order: Classes (types) -> Declarations (pure data) -> Private (shared helpers) -> Analysis (AST) -> Public (exports).
# Declarations before Analysis/Public so data is available if needed; Analysis before Public so wrappers can call it.
# AGENTS.md lists Classes -> Private -> Analysis -> Public; Declarations retained and ordered before Analysis (wall + data).
Get-ChildItem (Join-Path $moduleRoot 'Classes') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Declarations') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Private') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Analysis') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Public') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function @(
    'New-PSDrawIOPSAnalysis',
    'Get-PSDrawIOPSFunction',
    'Get-PSDrawIOPSClass',
    'Get-PSDrawIOPSEnum',
    'Get-PSDrawIOPSDependency',
    'Build-PSDrawIOPSGraph'
)
