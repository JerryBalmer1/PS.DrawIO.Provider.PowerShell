$PSDrawIOPowerShellShapes = @{
    PSFunction = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Functions'; Direction = 'Vertical' } }
    PSClass = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
    PSEnum = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
    PSModule = @{ Variants = @('Public'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Module'; Direction = 'Vertical' } }
    Internal = @{ Edge = $true }
    External = @{ Edge = $true }
    Unresolved = @{ Edge = $true }
    Inherits = @{ Edge = $true }
}
$null = $PSDrawIOPowerShellShapes
