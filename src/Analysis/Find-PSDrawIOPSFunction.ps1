function Find-PSDrawIOPSFunction {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Session)

    foreach ($entry in $Session.Asts.GetEnumerator()) {
        foreach ($ast in $entry.Value.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
            $parent = $ast.Parent
            $insideClass = $false
            while ($null -ne $parent) {
                if ($parent -is [System.Management.Automation.Language.TypeDefinitionAst]) {
                    $insideClass = $true
                    break
                }
                $parent = $parent.Parent
            }
            if ($insideClass) { continue }

            $paramBlock = $ast.Body.ParamBlock
            $binding = $paramBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'CmdletBinding' } | Select-Object -First 1
            $bindingArguments = [ordered]@{}
            if ($binding) {
                foreach ($argument in $binding.PositionalArguments) { $bindingArguments["Argument$($bindingArguments.Count)"] = $argument.Extent.Text }
                foreach ($argument in $binding.NamedArguments) { $bindingArguments[$argument.ArgumentName] = if ($argument.Argument) { $argument.Argument.Extent.Text } else { $true } }
            }
            $parameters = foreach ($parameter in @($paramBlock.Parameters)) {
                $parameterAttribute = $parameter.Attributes | Where-Object { $_.TypeName.Name -eq 'Parameter' } | Select-Object -First 1
                $namedArguments = @($parameterAttribute.NamedArguments)
                [pscustomobject]@{
                    Name = $parameter.Name.VariablePath.UserPath
                    Type = if ($parameter.StaticType) { $parameter.StaticType.FullName } else { $null }
                    Mandatory = [bool]($namedArguments | Where-Object ArgumentName -eq 'Mandatory')
                    ParameterSets = @($namedArguments | Where-Object ArgumentName -eq 'ParameterSetName' | ForEach-Object { $_.Argument.Extent.Text.Trim("'") })
                    ValueFromPipeline = [bool]($namedArguments | Where-Object ArgumentName -eq 'ValueFromPipeline')
                }
            }
            $bodyText = $ast.Body.Extent.Text
            $outputType = @($paramBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'OutputType' } | ForEach-Object { $_.PositionalArguments | ForEach-Object { $_.Extent.Text.Trim("'[]") } })
            # Path-based visibility: Public/ and default -> Public; Private/ -> Private.
            # Analysis/ is non-exported extraction surface (neither export variant) -> Internal.
            $visibility = if ($entry.Key -match '[\\/]Private[\\/]') {
                'Private'
            }
            elseif ($entry.Key -match '[\\/]Analysis[\\/]') {
                'Internal'
            }
            else {
                'Public'
            }
            [pscustomobject]@{
                Name = $ast.Name
                Visibility = $visibility
                CmdletBinding = [bool]$binding
                CmdletBindingArguments = [pscustomobject]$bindingArguments
                Parameters = @($parameters)
                ParameterSets = @($parameters | ForEach-Object ParameterSets | Select-Object -Unique)
                HasHelp = [bool]($bodyText -match '(?im)\.SYNOPSIS|\.DESCRIPTION|\.PARAMETER')
                OutputType = $outputType
                Path = $entry.Key
                Extent = Get-PSDrawIOPSAstExtent -Ast $ast
                Ast = $ast
            }
        }
    }
}
