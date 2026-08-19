$moduleRoot = Split-Path -Parent $PSCommandPath
Get-ChildItem (Join-Path $moduleRoot 'Classes') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Declarations') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Private') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Get-ChildItem (Join-Path $moduleRoot 'Public') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }
Export-ModuleMember -Function @(
    'New-PSDrawIOPSAnalysis',
    'Get-PSDrawIOPSFunction',
    'Get-PSDrawIOPSClass',
    'Get-PSDrawIOPSEnum',
    'Get-PSDrawIOPSDependency',
    'Build-PSDrawIOPSGraph'
)
