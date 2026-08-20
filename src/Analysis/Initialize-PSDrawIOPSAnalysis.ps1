function Initialize-PSDrawIOPSAnalysis {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $session = [PSAnalysisSession]::new($Path)
    foreach ($file in Get-PSDrawIOPSSourceFile -Path $session.Path) {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        $session.Files += $file.FullName
        if ($null -eq $ast) {
            $session.Confidence.ParseErrors += [pscustomobject]@{ Kind = 'ParseError'; Path = $file.FullName; Message = 'Unable to parse file.' }
            continue
        }
        $session.Asts[$file.FullName] = $ast
        foreach ($parseError in @($parseErrors)) {
            $session.Confidence.ParseErrors += [pscustomobject]@{ Kind = 'ParseError'; Path = $file.FullName; Message = $parseError.Message; Extent = Get-PSDrawIOPSAstExtent -Ast $parseError }
        }
        foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $firstElement = if ($command.CommandElements) { $command.CommandElements[0].Extent.Text } else { $null }
            if ($firstElement -eq '.') { continue }
            if (-not $command.GetCommandName()) {
                $kind = if ($command.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -or $firstElement -match '^\$') { 'DynamicInvocation' } else { 'UnresolvedInvocation' }
                $session.Confidence.Unresolved += [pscustomobject]@{ Kind = $kind; Path = $file.FullName; Extent = Get-PSDrawIOPSAstExtent -Ast $command }
            } elseif ($command.GetCommandName() -in 'Invoke-Expression', 'iex') {
                $session.Confidence.Unresolved += [pscustomobject]@{ Kind = 'DynamicInvocation'; Path = $file.FullName; Extent = Get-PSDrawIOPSAstExtent -Ast $command }
            }
        }
    }
    return $session
}
