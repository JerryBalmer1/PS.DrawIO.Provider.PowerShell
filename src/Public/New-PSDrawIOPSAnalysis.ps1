function New-PSDrawIOPSAnalysis {
    <#
    .SYNOPSIS
    Creates a static PowerShell AST analysis session.
    .PARAMETER Path
    A PowerShell file or directory to analyze.
    .EXAMPLE
    $session = New-PSDrawIOPSAnalysis -Path ./src
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)][string]$Path)

    if (-not $PSCmdlet.ShouldProcess($Path, 'Analyze PowerShell source')) { return }
    $session = [PSAnalysisSession]::new($Path)
    foreach ($file in Get-PSDrawIOSourceFile -Path $Path) {
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors)
        $session.Files += $file.FullName
        if ($null -eq $ast) {
            $session.Confidence.ParseErrors += [pscustomobject]@{ Kind = 'ParseError'; Path = $file.FullName; Message = 'Unable to parse file.' }
            continue
        }
        $session.Asts[$file.FullName] = $ast
        foreach ($parseError in @($parseErrors)) {
            $session.Confidence.ParseErrors += [pscustomobject]@{ Kind = 'ParseError'; Path = $file.FullName; Message = $parseError.Message; Extent = Get-PSDrawIOAstExtent -Ast $parseError }
        }
        foreach ($command in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            if (-not $command.GetCommandName()) {
                $session.Confidence.Unresolved += [pscustomobject]@{ Kind = 'UnresolvedInvocation'; Path = $file.FullName; Extent = Get-PSDrawIOAstExtent -Ast $command }
            } elseif ($command.GetCommandName() -in 'Invoke-Expression', 'iex') {
                $session.Confidence.Dynamic += [pscustomobject]@{ Kind = 'DynamicInvocation'; Path = $file.FullName; Extent = Get-PSDrawIOAstExtent -Ast $command }
            }
        }
    }
    return $session
}
