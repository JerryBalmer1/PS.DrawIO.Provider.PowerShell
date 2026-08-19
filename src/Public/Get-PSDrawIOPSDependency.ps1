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

    $functions = @(Get-PSDrawIOPSFunction -Session $Session)
    $names = @($functions.Name)
    $aliases = @{ gci = 'Get-ChildItem'; ls = 'Get-ChildItem'; dir = 'Get-ChildItem'; iex = 'Invoke-Expression' }
    foreach ($function in $functions) {
        foreach ($command in $function.Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $command.GetCommandName()
            if (-not $name) {
                $extent = Get-PSDrawIOPSAstExtent -Ast $command
                $firstElement = if ($command.CommandElements) { $command.CommandElements[0].Extent.Text } else { $null }
                $kind = if ($command.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -or $firstElement -match '^\$') { 'DynamicInvocation' } else { 'UnresolvedInvocation' }
                $Session.Confidence.Unresolved += [pscustomobject]@{ Kind = $kind; Path = $function.Path; Extent = $extent }
                [pscustomobject]@{ From = "Function:$($function.Name)"; To = "Unresolved:$($function.Name):$($extent.StartLine):$($extent.StartColumn)"; Type = 'Unresolved'; Extent = $extent }
                continue
            }
            $resolved = if ($aliases.ContainsKey($name.ToLowerInvariant())) { $aliases[$name.ToLowerInvariant()] } else { $name }
            $type = if ($names -contains $resolved) { 'Internal' } else { 'External' }
            if ($resolved -eq 'Invoke-Expression') { $type = 'Unresolved'; $Session.Confidence.Unresolved += [pscustomobject]@{ Kind = 'DynamicInvocation'; Path = $function.Path; Extent = Get-PSDrawIOPSAstExtent -Ast $command } }
            $targetId = if ($type -eq 'Internal') { "Function:$resolved" } elseif ($type -eq 'External') { "External:$resolved" } else { "Unresolved:$resolved" }
            $externalKind = $null
            if ($type -eq 'External') {
                $commandInfo = Get-Command -Name $resolved -ErrorAction SilentlyContinue | Select-Object -First 1
                $externalKind = if (-not $commandInfo) { 'Unknown' } elseif ($commandInfo.CommandType -eq 'Cmdlet' -and $commandInfo.ModuleName -match '^Microsoft\.PowerShell') { 'BuiltIn' } elseif ($commandInfo.ModuleName) { 'Module' } else { 'Unknown' }
            }
            [pscustomobject]@{ From = "Function:$($function.Name)"; To = $targetId; Type = $type; Name = $resolved; ExternalKind = $externalKind; Extent = Get-PSDrawIOPSAstExtent -Ast $command }
        }
    }
}
