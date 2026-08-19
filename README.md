# PS.DrawIO.Provider.PowerShell

Static PowerShell AST analysis for PS.DrawIO.

```powershell
Import-Module ./src/PS.DrawIO.Provider.PowerShell.psd1
$session = New-PSDrawIOPSAnalysis -Path ./src
$graph = Build-PSDrawIOPSGraph -Session $session
$graph | ConvertTo-Json -Depth 20
```

The module parses source without importing or executing the analysis target. It produces a `PSModuleGraph`; it does not emit draw.io XML or calculate layout.