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
}
