function Get-PSDrawIOPSEnum {
    <#
    .SYNOPSIS
    Gets enum declarations from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSEnum -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    Find-PSDrawIOPSEnum -Session $Session
}
