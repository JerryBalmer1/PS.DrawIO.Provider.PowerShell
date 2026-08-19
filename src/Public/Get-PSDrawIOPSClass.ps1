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
            $properties = foreach ($member in @($ast.Members | Where-Object { $_ -is [System.Management.Automation.Language.PropertyMemberAst] })) {
                [pscustomobject]@{ Name = $member.Name; Type = $member.PropertyType.TypeName.Name; IsStatic = $member.IsStatic; IsHidden = $member.IsHidden }
            }
            $methods = foreach ($member in @($ast.Members | Where-Object { $_ -is [System.Management.Automation.Language.FunctionMemberAst] })) {
                [pscustomobject]@{ Name = $member.Name; ReturnType = $member.ReturnType.TypeName.Name; IsStatic = $member.IsStatic; IsHidden = $member.IsHidden; Parameters = @($member.Parameters | ForEach-Object Name) }
            }
            [pscustomobject]@{ Name = $ast.Name; BaseType = if ($ast.BaseTypes) { $ast.BaseTypes[0].TypeName.Name } else { $null }; Properties = @($properties); Methods = @($methods); Path = $entry.Key; Extent = Get-PSDrawIOPSAstExtent -Ast $ast; Ast = $ast }
        }
    }
}
