[CmdletBinding()]
param([string]$Task = 'All')
& (Join-Path $PSScriptRoot 'build/build.ps1') -Task $Task
