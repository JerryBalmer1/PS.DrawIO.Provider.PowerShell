class PSModuleGraph {
    [string]$Path
    [string]$RootPath
    [object[]]$Nodes
    [object[]]$Edges
    [hashtable]$Analysis

    PSModuleGraph() {
        $this.Nodes = @()
        $this.Edges = @()
        $this.Analysis = @{}
    }
}
