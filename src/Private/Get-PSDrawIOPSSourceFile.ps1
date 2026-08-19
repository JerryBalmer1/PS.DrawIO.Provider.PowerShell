function Get-PSDrawIOPSSourceFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
    if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
        return @(Get-ChildItem -LiteralPath $resolved -Recurse -File | Where-Object Extension -in '.ps1', '.psm1', '.psd1')
    }
    return @(Get-Item -LiteralPath $resolved)
}