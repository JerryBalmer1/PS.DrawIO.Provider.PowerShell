function Get-PSDrawIOPSDependency {
    <#
    .SYNOPSIS
    Gets classified command dependencies from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSDependency -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    $functions = @(Get-PSDrawIOPSFunction -Session $Session)
    $names = @($functions.Name)
    $aliases = @{ gci = 'Get-ChildItem'; ls = 'Get-ChildItem'; dir = 'Get-ChildItem'; iex = 'Invoke-Expression' }
    foreach ($function in $functions) {
        foreach ($command in $function.Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $command.GetCommandName()
            if (-not $name) {
                $Session.Confidence.Unresolved += [pscustomobject]@{ Kind = 'UnresolvedInvocation'; Path = $function.Path; Extent = Get-PSDrawIOAstExtent -Ast $command }
                [pscustomobject]@{ From = $function.Name; To = $null; Type = 'Unresolved'; Extent = Get-PSDrawIOAstExtent -Ast $command }
                continue
            }
            $resolved = if ($aliases.ContainsKey($name.ToLowerInvariant())) { $aliases[$name.ToLowerInvariant()] } else { $name }
            $type = if ($names -contains $resolved) { 'Internal' } else { 'External' }
            if ($resolved -eq 'Invoke-Expression') { $type = 'Unresolved'; $Session.Confidence.Dynamic += [pscustomobject]@{ Kind = 'DynamicInvocation'; Path = $function.Path; Extent = Get-PSDrawIOAstExtent -Ast $command } }
            [pscustomobject]@{ From = $function.Name; To = $resolved; Type = $type; Extent = Get-PSDrawIOAstExtent -Ast $command }
        }
    }
}
