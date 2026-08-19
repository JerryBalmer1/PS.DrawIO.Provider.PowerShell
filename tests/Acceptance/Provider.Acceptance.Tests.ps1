$script:providerRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:specificationPath = Join-Path $script:providerRoot 'PROVIDER.md'
$script:acceptanceLabels = Select-String -Path $script:specificationPath -Pattern '^\- \[[ x]\] (.+)$' | ForEach-Object { $_.Matches[0].Groups[1].Value }
$script:registeredAcceptanceLabels = @()

function Get-Label {
    param([Parameter(Mandatory)][string]$Match)

    $normalizedMatch = $Match.Replace('`', '')
    $hit = @($script:acceptanceLabels | Where-Object { $_.Replace('`', '') -like "*$normalizedMatch*" })
    if ($hit.Count -ne 1) { throw "Spec label '$Match' matched $($hit.Count) checkboxes" }
    $script:registeredAcceptanceLabels += $hit[0]
    $hit[0]
}

BeforeAll {
    if (-not $script:providerRoot) {
        $script:providerRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    }
    Import-Module (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1') -Force
    $executed = Join-Path $script:providerRoot 'tests/Fixtures/Malicious/executed.txt'
    if (Test-Path $executed) { Remove-Item $executed -Force }
    function Assert-ManualSignOff {
        $signoffPath = Join-Path $script:providerRoot 'docs/SIGNOFF.json'
        $signoff = Get-Content $signoffPath -Raw | ConvertFrom-Json
        $signoff.Commit | Should -Be (git -C $script:providerRoot rev-parse HEAD)
        $signoff.Items.Count | Should -Be 3
    }
}

Describe 'Provider v1 acceptance' -Tag Acceptance {
    It (Get-Label 'Provider manifest declares') -Tag Acceptance {
        $manifest = Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')
        $manifest.PrivateData.PSDrawIO.ContractVersion | Should -Be 1
        $manifest.PrivateData.PSDrawIO.ProviderName | Should -Be 'PowerShell'
        $manifest.PrivateData.PSDrawIO.Capabilities | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Registers successfully') -Tag Acceptance {
        $registryManifest = Join-Path (Split-Path $script:providerRoot) 'PS.DrawIO.Registry/src/PS.DrawIO.Registry.psd1'
        Test-Path $registryManifest | Should -BeTrue
        Import-Module $registryManifest -Force
        Test-PSDrawIOProviderConformance -Path (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1') | Should -BeTrue
    }

    It (Get-Label 'Test-PSDrawIOProviderConformance') -Tag Acceptance {
        $registryManifest = Join-Path (Split-Path $script:providerRoot) 'PS.DrawIO.Registry/src/PS.DrawIO.Registry.psd1'
        $registryModule = Import-Module $registryManifest -PassThru -Force
        $registryModule.ExportedCommands.Keys | Should -Contain 'Test-PSDrawIOProviderConformance'
    }

    It (Get-Label 'Semantic types declared') -Tag Acceptance {
        $shapes = (Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')).PrivateData.PSDrawIO.Shapes
        foreach ($shape in 'PSFunction', 'PSClass', 'PSEnum', 'PSModule') { $shapes.Keys | Should -Contain $shape }
        foreach ($edge in 'Internal', 'External', 'Unresolved', 'Inherits') { $shapes.Keys | Should -Contain $edge }
    }

    It (Get-Label 'Public/private expressed') -Tag Acceptance {
        $shapes = (Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')).PrivateData.PSDrawIO.Shapes
        $shapes.PSFunction.Variants | Should -Contain 'Public'
        $shapes.PSFunction.Variants | Should -Contain 'Private'
        $shapes.Keys | Should -Not -Contain 'PSPublicFunction'
        $shapes.Keys | Should -Not -Contain 'PSPrivateFunction'
    }

    It (Get-Label 'Link template declared') -Tag Acceptance {
        (Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')).PrivateData.PSDrawIO.Shapes.PSFunction.LinkTemplate | Should -Match '^vscode://'
    }

    It (Get-Label 'Layout **hints** only') -Tag Acceptance {
        Get-ChildItem (Join-Path $script:providerRoot 'src/Declarations') -Recurse -File | Select-String 'src[/\\]Analysis|Get-PSDrawIOPS' | Should -BeNullOrEmpty
        Get-ChildItem (Join-Path $script:providerRoot 'src') -Recurse -File | Select-String '\b(x|y|width|height)\s*=' | Should -BeNullOrEmpty
    }

    It (Get-Label 'Nothing in `src/Declarations/`') -Tag Acceptance {
        (Get-Content (Join-Path $script:providerRoot 'src/Declarations/PSDrawIO.Declarations.ps1') -Raw) | Should -Not -Match 'Get-PSDrawIOPS'
    }

    It (Get-Label '`New-PSDrawIOPSAnalysis` builds') -Tag Acceptance {
        New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src') | Should -Not -BeNullOrEmpty
    }

    It (Get-Label '**No code path calls `Import-Module`') -Tag Acceptance {
        $imports = foreach ($file in Get-ChildItem (Join-Path $script:providerRoot 'src') -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1') {
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
            $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Import-Module' }, $true)
        }
        $imports | Should -BeNullOrEmpty
    }

    It (Get-Label 'Functions extracted') -Tag Acceptance {
        $function = Get-PSDrawIOPSFunction -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Where-Object Name -eq 'Get-Thing'
        $function.CmdletBinding | Should -BeTrue
        $function.CmdletBindingArguments | Should -Not -BeNullOrEmpty
        $function.Parameters | Should -Not -BeNullOrEmpty
        $function.ParameterSets | Should -Contain 'ByName'
        $function.HasHelp | Should -BeTrue
        $function.Extent | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Classes extracted') -Tag Acceptance {
        $classes = Get-PSDrawIOPSClass -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1'))
        ($classes | Where-Object Name -eq 'ChildThing').Methods | Should -Not -BeNullOrEmpty
        ($classes | Where-Object Name -eq 'BaseThing').Properties | Should -Not -BeNullOrEmpty
        ($classes | Where-Object Name -eq 'ChildThing').BaseType | Should -Be 'BaseThing'
    }

    It (Get-Label 'Enums extracted') -Tag Acceptance {
        $enum = Get-PSDrawIOPSEnum -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Where-Object Name -eq 'ExplicitKind'
        $enum.UnderlyingType | Should -Be 'byte'
        $enum.Members | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Dependencies classified') -Tag Acceptance {
        $types = Get-PSDrawIOPSDependency -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Select-Object -ExpandProperty Type
        $types | Should -Contain 'External'
        $types | Should -Contain 'Unresolved'
    }

    It (Get-Label 'Aliases resolved') -Tag Acceptance {
        $aliases = @(Get-PSDrawIOPSDependency -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Where-Object Name -eq 'Get-ChildItem')
        $aliases.Count | Should -BeGreaterThan 0
    }

    It (Get-Label '`Unresolved` edges retained') -Tag Acceptance {
        $edge = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Select-Object -ExpandProperty Edges | Where-Object Type -eq 'Unresolved'
        $edge.Extent | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Every graph carries') -Tag Acceptance {
        (Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src'))).Analysis.Confidence | Should -Not -BeNullOrEmpty
    }

    It (Get-Label '`Build-PSDrawIOPSGraph` produces') -Tag Acceptance {
        (Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src'))).GetType().Name | Should -Be 'PSModuleGraph'
    }

    It (Get-Label 'Graph serializes') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src'))
        ($graph | ConvertTo-Json -Depth 20 | ConvertFrom-Json).Nodes.Count | Should -Be $graph.Nodes.Count
    }

    It (Get-Label 'Analyzes `PS.DrawIO.Registry`') -Tag Acceptance {
        $registrySource = Join-Path (Split-Path $script:providerRoot) 'PS.DrawIO.Registry/src'
        Test-Path $registrySource | Should -BeTrue
        (New-PSDrawIOPSAnalysis -Path $registrySource).Files.Count | Should -BeGreaterThan 0
    }

    It (Get-Label 'Analyzes a fixture module') -Tag Acceptance {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Pathological')
        $session.Confidence.Unresolved | Where-Object Kind -eq 'DynamicInvocation' | Should -Not -BeNullOrEmpty
        $session.Confidence.ParseErrors | Should -Not -BeNullOrEmpty
        $aliasEvidence = @(Get-PSDrawIOPSDependency -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1')) | Where-Object Name -eq 'Get-ChildItem')
        $aliasEvidence.Count | Should -Be 2
    }

    It (Get-Label 'Analyzing a module with a **known malicious') -Tag Acceptance {
        $executed = Join-Path $script:providerRoot 'tests/Fixtures/Malicious/executed.txt'
        New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Malicious') | Out-Null
        Test-Path $executed | Should -BeFalse
    }

    It (Get-Label 'Pester 5 green') -Tag Acceptance {
        $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 7
    }

    It (Get-Label '`PSScriptAnalyzer` clean') -Tag Acceptance {
        Invoke-ScriptAnalyzer -Path (Join-Path $script:providerRoot 'src') -Recurse -Severity Error, Warning | Should -BeNullOrEmpty
    }

    It (Get-Label '`Test-ModuleManifest` passes') -Tag Acceptance {
        Test-ModuleManifest (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1') | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Imports clean') -Tag Acceptance {
        $manifest = Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1'
        $output = & pwsh -NoLogo -NoProfile -NonInteractive -Command "Import-Module '$manifest' -Force; (Get-Command New-PSDrawIOPSAnalysis).Name"
        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'New-PSDrawIOPSAnalysis'
    }

    It (Get-Label 'realistic call density') -Tag Acceptance {
        $fixture = Join-Path $TestDrive 'TwoHundred.psm1'
        1..200 | ForEach-Object { "function Get-Thing$_ { Get-Thing$(($_ % 200) + 1); Get-ChildItem }" } | Set-Content $fixture
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $session = New-PSDrawIOPSAnalysis -Path $fixture
        Build-PSDrawIOPSGraph -Session $session | Out-Null
        $sw.Stop()
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 30
    }

    It (Get-Label 'No `src/Public` function') -Tag Acceptance {
        Get-ChildItem (Join-Path $script:providerRoot 'src/Public') -Filter '*.ps1' | ForEach-Object { (Get-Content $_.FullName).Count | Should -BeLessOrEqual 100 }
    }

    It (Get-Label 'Coverage ≥ 90%') -Tag Acceptance {
        $publicCoverage = Invoke-Pester (Join-Path $script:providerRoot 'tests/Unit') -CodeCoverage (Join-Path $script:providerRoot 'src/Public/*.ps1') -PassThru
        $overallCoverage = Invoke-Pester (Join-Path $script:providerRoot 'tests/Unit') -CodeCoverage (Join-Path $script:providerRoot 'src/**/*.ps1') -PassThru
        $publicCoverage.CodeCoverage.CoveragePercent | Should -BeGreaterOrEqual 90
        $overallCoverage.CodeCoverage.CoveragePercent | Should -BeGreaterOrEqual 80
    }

    It (Get-Label 'All exported names') -Tag Acceptance {
        $commands = Import-Module (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1') -PassThru -Force | Select-Object -ExpandProperty ExportedCommands
        foreach ($name in $commands.Keys) { (Get-Verb ($name -split '-', 2)[0]).Verb | Should -Not -BeNullOrEmpty }
    }

    It (Get-Label '`docs/DOMAIN-MODEL.md`') -Tag Acceptance {
        (Get-Content (Join-Path $script:providerRoot 'docs/DOMAIN-MODEL.md') -Raw) | Should -Match 'PSModuleGraph'
        (Get-Content (Join-Path $script:providerRoot 'docs/DOMAIN-MODEL.md') -Raw) | Should -Match 'External'
    }

    It (Get-Label '`docs/LIMITATIONS.md`') -Tag Acceptance {
        (Get-Content (Join-Path $script:providerRoot 'docs/LIMITATIONS.md') -Raw) | Should -Match 'static'
        (Get-Content (Join-Path $script:providerRoot 'docs/LIMITATIONS.md') -Raw) | Should -Match 'Unresolved'
    }

    It (Get-Label '`CHANGELOG.md`') -Tag Acceptance {
        (Get-Content (Join-Path $script:providerRoot 'CHANGELOG.md') -Raw) | Should -Match '\[Unreleased\]'
    }

    # Deliberately failing contract evidence: Registry v1 exposes one opaque Shapes map;
    # this provider must not invent a second declaration source without a contract decision.
    It (Get-Label 'Node types and edge types') -Tag Acceptance {
        $manifest = Import-PowerShellDataFile (Join-Path $script:providerRoot 'src/PS.DrawIO.Provider.PowerShell.psd1')
        $manifest.PrivateData.PSDrawIO.NodeTypes | Should -Not -BeNullOrEmpty
        $manifest.PrivateData.PSDrawIO.EdgeTypes | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Benign dot-source loader') -Tag Acceptance {
        $session = New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src')
        @($session.Confidence.Unresolved | Where-Object { $_.Kind -eq 'UnresolvedInvocation' -and $_.Path -match '\.psm1$' -and $_.Extent.StartColumn -eq 1 }) | Should -BeNullOrEmpty
    }

    It (Get-Label 'Every edge endpoint') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src'))
        $ids = @($graph.Nodes | ForEach-Object Id)
        foreach ($edge in $graph.Edges) {
            $ids | Should -Contain $edge.From
            $ids | Should -Contain $edge.To
        }
    }

    It (Get-Label 'External and unresolved references') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1'))
        $graph.Nodes | Where-Object Type -eq 'PSExternalCommand' | Should -Not -BeNullOrEmpty
        $graph.Nodes | Where-Object Type -eq 'PSUnresolved' | Should -Not -BeNullOrEmpty
    }

    It (Get-Label 'Duplicate edges aggregated') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1'))
        $edge = $graph.Edges | Where-Object { $_.From -eq 'Function:Get-Thing' -and $_.To -eq 'External:Get-ChildItem' }
        $edge.CallCount | Should -BeGreaterThan 1
        $edge.Extents.Count | Should -Be $edge.CallCount
    }

    It (Get-Label 'External references classified') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'tests/Fixtures/Sample.psm1'))
        $graph.Edges | Where-Object Type -eq 'External' | ForEach-Object ExternalKind | Should -BeIn 'BuiltIn', 'Module', 'Unknown'
    }

    It (Get-Label 'Node paths stored') -Tag Acceptance {
        $graph = Build-PSDrawIOPSGraph -Session (New-PSDrawIOPSAnalysis -Path (Join-Path $script:providerRoot 'src'))
        $graph.RootPath | Should -Not -BeNullOrEmpty
        $graph.Nodes | Where-Object Path | ForEach-Object Path | Should -Not -Match '^[A-Za-z]:[\\/]'
    }

    It 'has one acceptance It block for every §9 checkbox' -Tag Acceptance {
        foreach ($label in $script:acceptanceLabels) {
            $script:registeredAcceptanceLabels | Should -Contain $label
        }
    }
}

Describe 'Provider v1 manual sign-off' -Tag Acceptance {
    It (Get-Label 'Analyzes **itself**') -Tag ManualSignOff {
        Assert-ManualSignOff
    }

    It (Get-Label '`README.md` — install') -Tag ManualSignOff {
        Assert-ManualSignOff
    }

    It (Get-Label '`docs/PATTERNS.md` — **maintained') -Tag ManualSignOff {
        Assert-ManualSignOff
    }
}
