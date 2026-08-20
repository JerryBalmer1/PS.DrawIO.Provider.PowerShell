Import-Module ./src/PS.DrawIO.Provider.PowerShell.psd1 -Force

$session = New-PSDrawIOPSAnalysis -Path ./src
$graph = Build-PSDrawIOPSGraph -Session $session

$graph | ConvertTo-Json -Depth 20

$graph.Nodes
$graph.Edges
$graph.Analysis.Confidence