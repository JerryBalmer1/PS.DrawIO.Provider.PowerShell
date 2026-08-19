@{
    RootModule = 'PS.DrawIO.Provider.PowerShell.psm1'
    ModuleVersion = '1.0.0'
    GUID = '2f5d8c1f-7b83-4d52-a10e-8c87ccf8b3fd'
    Author = 'Jerry Balmer'
    Description = 'Static PowerShell AST analyzer and PS.DrawIO provider.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'New-PSDrawIOPSAnalysis',
        'Get-PSDrawIOPSFunction',
        'Get-PSDrawIOPSClass',
        'Get-PSDrawIOPSEnum',
        'Get-PSDrawIOPSDependency',
        'Build-PSDrawIOPSGraph'
    )
    PrivateData = @{
        PSData = @{ Tags = @('PSDrawIO', 'PowerShell', 'AST') }
        PSDrawIO = @{
            ContractVersion = 1
            ProviderName = 'PowerShell'
            Capabilities = @('Shapes', 'Links', 'LayoutHints', 'Analysis')
            Shapes = @{
                PSFunction = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Functions'; Direction = 'Vertical' } }
                PSClass = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
                PSEnum = @{ Variants = @('Public', 'Private'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Types'; Direction = 'Vertical' } }
                PSModule = @{ Variants = @('Public'); LinkTemplate = 'vscode://file/{path}:{line}'; LayoutHints = @{ Group = 'Module'; Direction = 'Vertical' } }
                Internal = @{ Edge = $true }
                External = @{ Edge = $true }
                Unresolved = @{ Edge = $true }
                Inherits = @{ Edge = $true }
            }
        }
    }
}
