class PSAnalysisSession {
    [string]$Path
    [string]$RootPath
    [object[]]$Files
    [hashtable]$Asts
    [hashtable]$Confidence

    PSAnalysisSession([string]$Path) {
        $this.Path = (Resolve-Path -LiteralPath $Path).Path
        $this.RootPath = $this.Path
        $this.Files = @()
        $this.Asts = @{}
        $this.Confidence = [ordered]@{
            ParseErrors = @()
            Unresolved = @()
        }
    }
}
