function Get-Thing {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Name
    )
    gci $Name
    & $dynamicCommand
}
class BaseThing { [string]$Name }
class ChildThing : BaseThing { [void]Run() {} }
enum Kind { One = 1; Two = 2 }
