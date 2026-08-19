function Get-PSDrawIOPSClass {
    <#
    .SYNOPSIS
    Gets class declarations from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSClass -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    foreach ($entry in $Session.Asts.GetEnumerator()) {
        foreach ($ast in $entry.Value.FindAll({ param($node) $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and $node.IsClass }, $true)) {
            [pscustomobject]@{ Name = $ast.Name; BaseType = if ($ast.BaseTypes) { $ast.BaseTypes[0].TypeName.Name } else { $null }; Properties = @($ast.Members | Where-Object { $_ -is [System.Management.Automation.Language.PropertyMemberAst] } | ForEach-Object Name); Methods = @($ast.Members | Where-Object { $_ -is [System.Management.Automation.Language.FunctionMemberAst] } | ForEach-Object Name); Path = $entry.Key; Extent = Get-PSDrawIOAstExtent -Ast $ast; Ast = $ast }
        }
    }
}
