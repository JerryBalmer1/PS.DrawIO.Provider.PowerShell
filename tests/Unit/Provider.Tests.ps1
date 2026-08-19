BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../src/PS.DrawIO.Provider.PowerShell.psd1') -Force
}

Describe 'PowerShell provider analysis' {
    It 'parses without importing the target' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Malicious')
        Test-Path (Join-Path $PSScriptRoot '../Fixtures/Malicious/executed.txt') | Should -BeFalse
        $session | Should -Not -BeNullOrEmpty
    }

    It 'extracts functions, classes, enums, and confidence gaps' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        (Get-PSDrawIOPSFunction -Session $session).Name | Should -Contain 'Get-Thing'
        (Get-PSDrawIOPSClass -Session $session).Name | Should -Contain 'ChildThing'
        (Get-PSDrawIOPSEnum -Session $session).Name | Should -Contain 'Kind'
        $session.Confidence.Unresolved.Count | Should -BeGreaterThan 0
    }

    It 'builds a graph and round trips through JSON' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $graph = Build-PSDrawIOPSGraph -Session $session
        $graph.Nodes.Count | Should -BeGreaterThan 0
        $json = $graph | ConvertTo-Json -Depth 20
        $json | ConvertFrom-Json | ForEach-Object { $_.Nodes.Count } | Should -Be $graph.Nodes.Count
    }

    It 'uses node IDs for edge endpoints and closes external references' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $graph = Build-PSDrawIOPSGraph -Session $session
        $nodeIds = @($graph.Nodes | ForEach-Object Id)

        foreach ($edge in $graph.Edges) {
            $nodeIds | Should -Contain $edge.From
            $nodeIds | Should -Contain $edge.To
        }

        $graph.Nodes | Where-Object { $_.Type -eq 'PSExternalCommand' -and $_.Name -eq 'Get-ChildItem' } | Should -Not -BeNullOrEmpty
    }

    It 'excludes class constructors and methods from module functions' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../../src')
        $functions = @(Get-PSDrawIOPSFunction -Session $session)

        $functions.Name | Should -Not -Contain 'PSModuleGraph'
        $functions.Name | Should -Not -Contain 'ToString'
        @($functions | Where-Object Visibility -eq 'Public').Count | Should -Be 6
        @($functions | Where-Object Visibility -eq 'Private').Count | Should -Be 2
    }

    It 'extracts class members and inheritance metadata' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $baseClass = Get-PSDrawIOPSClass -Session $session | Where-Object Name -eq 'BaseThing'
        $class = Get-PSDrawIOPSClass -Session $session | Where-Object Name -eq 'ChildThing'

        $baseClass.Properties.Name | Should -Contain 'Name'
        $baseClass.Properties.Type | Should -Contain 'string'
        $class.BaseType | Should -Be 'BaseThing'
        $class.Methods.Name | Should -Contain 'Run'
        $class.Methods | Where-Object Name -eq 'Run' | Select-Object -ExpandProperty IsStatic | Should -BeFalse
    }

    It 'extracts function binding parameters help and output metadata' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $function = Get-PSDrawIOPSFunction -Session $session | Where-Object Name -eq 'Get-Thing'

        $function.CmdletBinding | Should -BeTrue
        $function.CmdletBindingArguments.SupportsShouldProcess | Should -BeTrue
        $function.Parameters.Name | Should -Contain 'Name'
        $function.Parameters.Mandatory | Should -Contain 'True'
        $function.Parameters.ParameterSets | Should -Contain 'ByName'
        $function.HasHelp | Should -BeTrue
        $function.OutputType | Should -Contain 'System.IO.FileInfo'
    }

    It 'collapses unresolved confidence findings and ignores dot-source boilerplate' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../../src')

        $session.Confidence.PSObject.Properties.Name | Should -Not -Contain 'Dynamic'
        @($session.Confidence.Unresolved | Where-Object Kind -eq 'DynamicInvocation').Count | Should -BeGreaterThan 0
        @($session.Confidence.Unresolved | Where-Object { $_.Path -match '\.psm1$' -and $_.Extent.StartColumn -eq 1 -and $_.Kind -eq 'UnresolvedInvocation' }).Count | Should -Be 0
    }

    It 'subdivides external dependencies' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $graph = Build-PSDrawIOPSGraph -Session $session

        $graph.Edges | Where-Object { $_.Name -eq 'Get-ChildItem' } | Select-Object -ExpandProperty ExternalKind | Should -Contain 'BuiltIn'
        $graph.Edges | Where-Object Type -eq 'External' | ForEach-Object ExternalKind | Should -BeIn 'BuiltIn', 'Module', 'Unknown'
    }

    It 'aggregates duplicate edges and keeps all call extents' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $graph = Build-PSDrawIOPSGraph -Session $session
        $edge = $graph.Edges | Where-Object { $_.From -eq 'Function:Get-Thing' -and $_.To -eq 'External:Get-ChildItem' }

        @($graph.Edges | Where-Object { $_.From -eq 'Function:Get-Thing' -and $_.To -eq 'External:Get-ChildItem' }).Count | Should -Be 1
        $edge.CallCount | Should -Be 2
        $edge.Extents.Count | Should -Be 2
    }

    It 'stores node paths relative to one analysis root' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '../../src')).Path
        $session = New-PSDrawIOPSAnalysis -Path $root
        $graph = Build-PSDrawIOPSGraph -Session $session

        $graph.RootPath | Should -Be $root
        $graph.Nodes | Where-Object Path | ForEach-Object Path | Should -Not -Match '^[A-Za-z]:[\\/]'
    }

    It 'extracts enum underlying types and members' {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $PSScriptRoot '../Fixtures/Sample.psm1')
        $enum = Get-PSDrawIOPSEnum -Session $session | Where-Object Name -eq 'ExplicitKind'

        $enum.UnderlyingType | Should -Be 'byte'
        $enum.Members.Name | Should -Contain 'First'
        $enum.Members.Value | Should -Contain '1'
    }

    It 'uses the PSDrawIOPS prefix for private helper functions' {
        $privateFiles = Get-ChildItem (Join-Path $PSScriptRoot '../../src/Private') -Filter '*.ps1'

        $privateFiles.BaseName | Should -Not -Contain 'Get-PSDrawIOAstExtent'
        $privateFiles.BaseName | Should -Not -Contain 'Get-PSDrawIOSourceFile'
        $privateFiles.BaseName | Should -Contain 'Get-PSDrawIOPSAstExtent'
        $privateFiles.BaseName | Should -Contain 'Get-PSDrawIOPSSourceFile'
    }

    It 'records parser errors with the source path and message' {
        $fixture = Join-Path $TestDrive 'ParseError.psm1'
        'function Broken {' | Set-Content -LiteralPath $fixture

        $session = New-PSDrawIOPSAnalysis -Path $fixture
        $error = @($session.Confidence.ParseErrors) | Select-Object -First 1

        $error.Kind | Should -Be 'ParseError'
        $error.Path | Should -Be (Resolve-Path $fixture).Path
        $error.Message | Should -Match 'Missing closing'
        $error.Extent.StartLine | Should -Be 1
    }

    It 'records dynamic invocation confidence with kind and extent' {
        $fixture = Join-Path $TestDrive 'Dynamic.psm1'
        @(
            'function Invoke-Dynamic {'
            '    & $cmd'
            '}'
        ) | Set-Content -LiteralPath $fixture

        $session = New-PSDrawIOPSAnalysis -Path $fixture
        $finding = @($session.Confidence.Unresolved) | Where-Object Kind -eq 'DynamicInvocation' | Select-Object -First 1

        $finding.Kind | Should -Be 'DynamicInvocation'
        $finding.Path | Should -Be (Resolve-Path $fixture).Path
        $finding.Extent.StartLine | Should -Be 2
        $finding.Extent.StartColumn | Should -Be 5

        $dependency = Get-PSDrawIOPSDependency -Session $session | Where-Object From -eq 'Function:Invoke-Dynamic'
        $dependency.Type | Should -Be 'Unresolved'
        $dependency.To | Should -Match '^Unresolved:Invoke-Dynamic:2:5$'
        @($session.Confidence.Unresolved | Where-Object { $_.Kind -eq 'DynamicInvocation' -and $_.Extent.StartLine -eq 2 }).Count | Should -BeGreaterThan 1
    }

    It 'classifies external module commands' {
        $fixture = Join-Path $TestDrive 'ModuleCommand.psm1'
        'function Use-ModuleCommand { Describe "example" }' | Set-Content -LiteralPath $fixture

        $dependencies = Get-PSDrawIOPSDependency -Session (New-PSDrawIOPSAnalysis -Path $fixture)
        $dependency = $dependencies | Where-Object Name -eq 'Describe'

        $dependency.Type | Should -Be 'External'
        $dependency.ExternalKind | Should -Be 'Module'
    }

    It 'classifies unresolved external commands as unknown' {
        $fixture = Join-Path $TestDrive 'UnknownCommand.psm1'
        'function Use-UnknownCommand { Invoke-DefinitelyMissingPSDrawIOPSCommand }' | Set-Content -LiteralPath $fixture

        $dependencies = Get-PSDrawIOPSDependency -Session (New-PSDrawIOPSAnalysis -Path $fixture)
        $dependency = $dependencies | Where-Object Name -eq 'Invoke-DefinitelyMissingPSDrawIOPSCommand'

        $dependency.Type | Should -Be 'External'
        $dependency.ExternalKind | Should -Be 'Unknown'
    }

    It 'captures named CmdletBinding arguments' {
        $fixture = Join-Path $TestDrive 'BindingArguments.psm1'
        @(
            'function Save-Thing {'
            '    [CmdletBinding(SupportsShouldProcess)]'
            '    param()'
            '}'
        ) | Set-Content -LiteralPath $fixture

        $function = Get-PSDrawIOPSFunction -Session (New-PSDrawIOPSAnalysis -Path $fixture) | Where-Object Name -eq 'Save-Thing'

        $function.CmdletBinding | Should -BeTrue
        $function.CmdletBindingArguments.SupportsShouldProcess | Should -BeTrue
    }
}
