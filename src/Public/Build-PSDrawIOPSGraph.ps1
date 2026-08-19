function Build-PSDrawIOPSGraph {
    <#
    .SYNOPSIS
    Builds a serializable PowerShell module graph.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Build-PSDrawIOPSGraph -Session $session | ConvertTo-Json -Depth 10
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    $graph = [PSModuleGraph]::new()
    $graph.Path = $Session.Path
    $graph.Analysis = @{ Confidence = $Session.Confidence }
    foreach ($function in Get-PSDrawIOPSFunction -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Function:$($function.Name)"; Type = 'PSFunction'; Name = $function.Name; Visibility = $function.Visibility; Path = $function.Path; Extent = $function.Extent } }
    foreach ($class in Get-PSDrawIOPSClass -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Class:$($class.Name)"; Type = 'PSClass'; Name = $class.Name; Path = $class.Path; Extent = $class.Extent } }
    foreach ($enum in Get-PSDrawIOPSEnum -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Enum:$($enum.Name)"; Type = 'PSEnum'; Name = $enum.Name; Path = $enum.Path; Extent = $enum.Extent } }
    foreach ($edge in Get-PSDrawIOPSDependency -Session $Session) { $graph.Edges += $edge }
    return $graph
}
