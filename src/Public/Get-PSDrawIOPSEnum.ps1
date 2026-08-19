function Get-PSDrawIOPSEnum {
    <#
    .SYNOPSIS
    Gets enum declarations from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSEnum -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    foreach ($entry in $Session.Asts.GetEnumerator()) {
        foreach ($ast in $entry.Value.FindAll({ param($node) $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and $node.IsEnum }, $true)) {
            [pscustomobject]@{ Name = $ast.Name; UnderlyingType = $ast.BaseTypes[0].TypeName.Name; Members = @($ast.Members | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Value = $_.Value } }); Path = $entry.Key; Extent = Get-PSDrawIOAstExtent -Ast $ast; Ast = $ast }
        }
    }
}
