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
    Initialize-PSDrawIOPSAnalysis -Path $Path
}
