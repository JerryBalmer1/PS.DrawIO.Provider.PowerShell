function Get-Thing {
    <#
    .SYNOPSIS
    Gets a thing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByName')]
        [string]$Name
    )
    gci $Name
    gci $Name
    & $dynamicCommand
}
class BaseThing { [string]$Name }
class ChildThing : BaseThing { [void]Run() {} }
enum Kind { One = 1; Two = 2 }
enum ExplicitKind : byte { First = 1; Second = 2 }
