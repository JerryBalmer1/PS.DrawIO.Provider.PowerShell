function Get-PSDrawIOPSFunction {
    <#
    .SYNOPSIS
    Gets function declarations from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSFunction -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    foreach ($entry in $Session.Asts.GetEnumerator()) {
        foreach ($ast in $entry.Value.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            $binding = $ast.Body.ParamBlock.Attributes | Where-Object TypeName -match '^CmdletBinding$' | Select-Object -First 1
            [pscustomobject]@{
                Name = $ast.Name; Visibility = 'Public'; CmdletBinding = [bool]$binding; Parameters = @($ast.Parameters | ForEach-Object Name); Path = $entry.Key; Extent = Get-PSDrawIOAstExtent -Ast $ast; Ast = $ast
            }
        }
    }
}
