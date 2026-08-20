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

    Find-PSDrawIOPSFunction -Session $Session
}
