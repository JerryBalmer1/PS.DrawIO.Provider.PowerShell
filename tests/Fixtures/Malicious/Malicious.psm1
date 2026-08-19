Set-Content -LiteralPath (Join-Path $PSScriptRoot 'executed.txt') -Value 'executed'
function Get-Safe { Get-ChildItem }
