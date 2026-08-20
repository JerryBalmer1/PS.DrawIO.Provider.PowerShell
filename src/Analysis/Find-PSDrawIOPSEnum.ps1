function Find-PSDrawIOPSEnum {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    foreach ($entry in $Session.Asts.GetEnumerator()) {
        foreach ($ast in $entry.Value.FindAll({ param($node) $node -is [System.Management.Automation.Language.TypeDefinitionAst] -and $node.IsEnum }, $true)) {
            [pscustomobject]@{ Name = $ast.Name; UnderlyingType = $ast.BaseTypes[0].TypeName.Name; Members = @($ast.Members | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Value = if ($_.InitialValue) { $_.InitialValue.Extent.Text } else { $null } } }); Path = $entry.Key; Extent = Get-PSDrawIOPSAstExtent -Ast $ast; Ast = $ast }
        }
    }
}
