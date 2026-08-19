function Get-PSDrawIOPSAstExtent {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Ast)

    [pscustomobject]@{ StartLine = $Ast.Extent.StartLineNumber; StartColumn = $Ast.Extent.StartColumnNumber; EndLine = $Ast.Extent.EndLineNumber; EndColumn = $Ast.Extent.EndColumnNumber }
}