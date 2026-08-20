function Build-PSDrawIOPSModuleGraph {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    $graph = [PSModuleGraph]::new()
    $graph.Path = $Session.Path
    $graph.RootPath = $Session.RootPath
    $graph.Analysis = @{ Confidence = $Session.Confidence }
    $relativePath = { param($path) if ($Session.RootPath -eq $path) { Split-Path -Leaf $path } else { [IO.Path]::GetRelativePath($Session.RootPath, $path) } }
    foreach ($function in Find-PSDrawIOPSFunction -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Function:$($function.Name)"; Type = 'PSFunction'; Name = $function.Name; Visibility = $function.Visibility; Path = (& $relativePath $function.Path); Extent = $function.Extent } }
    foreach ($class in Find-PSDrawIOPSClass -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Class:$($class.Name)"; Type = 'PSClass'; Name = $class.Name; Path = (& $relativePath $class.Path); Extent = $class.Extent } }
    foreach ($enum in Find-PSDrawIOPSEnum -Session $Session) { $graph.Nodes += [pscustomobject]@{ Id = "Enum:$($enum.Name)"; Type = 'PSEnum'; Name = $enum.Name; Path = (& $relativePath $enum.Path); Extent = $enum.Extent } }
    $allEdges = @()
    foreach ($class in Find-PSDrawIOPSClass -Session $Session) {
        if ($class.BaseType -and (Find-PSDrawIOPSClass -Session $Session | Where-Object Name -eq $class.BaseType)) {
            $allEdges += [pscustomobject]@{ From = "Class:$($class.Name)"; To = "Class:$($class.BaseType)"; Type = 'Inherits'; Extent = $class.Extent }
        }
    }
    foreach ($edge in Find-PSDrawIOPSDependency -Session $Session) {
        $allEdges += $edge
    }
    foreach ($group in @($allEdges | Group-Object { "$($_.From)|$($_.To)" })) {
        $first = $group.Group[0]
        $graph.Edges += [pscustomobject]@{ From = $first.From; To = $first.To; Type = $first.Type; Name = $first.Name; ExternalKind = $first.ExternalKind; CallCount = $group.Count; Extent = $first.Extent; Extents = @($group.Group | ForEach-Object Extent) }
        if ($first.Type -eq 'External' -and -not ($graph.Nodes | Where-Object Id -eq $first.To)) {
            $graph.Nodes += [pscustomobject]@{ Id = $first.To; Type = 'PSExternalCommand'; Name = $first.Name; ExternalKind = $first.ExternalKind; Path = $null; Extent = $first.Extent }
        } elseif ($first.Type -eq 'Unresolved' -and -not ($graph.Nodes | Where-Object Id -eq $first.To)) {
            $graph.Nodes += [pscustomobject]@{ Id = $first.To; Type = 'PSUnresolved'; Name = $first.Name; Path = $null; Extent = $first.Extent }
        }
    }
    return $graph
}
