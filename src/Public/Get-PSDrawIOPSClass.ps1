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

    Find-PSDrawIOPSClass -Session $Session
}
