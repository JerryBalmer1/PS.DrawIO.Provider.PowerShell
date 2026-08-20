function Get-PSDrawIOPSDependency {
    <#
    .SYNOPSIS
    Gets classified command dependencies from an analysis session.
    .PARAMETER Session
    Analysis session created by New-PSDrawIOPSAnalysis.
    .EXAMPLE
    Get-PSDrawIOPSDependency -Session $session
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    Find-PSDrawIOPSDependency -Session $Session
}
