function Build-PSDrawIOPSGraph {
    <#
    .SYNOPSIS
    Builds a serializable PowerShell module graph.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Build-PSDrawIOPSGraph -Session $session | ConvertTo-Json -Depth 10
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    Build-PSDrawIOPSModuleGraph -Session $Session
}
