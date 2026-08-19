class PSAnalysisSession {
    [string]$Path
    [object[]]$Files
    [hashtable]$Asts
    [hashtable]$Confidence

    PSAnalysisSession([string]$Path) {
        $this.Path = $Path
        $this.Files = @()
        $this.Asts = @{}
        $this.Confidence = [ordered]@{
            ParseErrors = @()
            Unresolved = @()
            Dynamic = @()
        }
    }
}
