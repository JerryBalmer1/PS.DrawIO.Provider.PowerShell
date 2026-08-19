class PSModuleGraph {
    [string]$Path
    [object[]]$Nodes
    [object[]]$Edges
    [hashtable]$Analysis

    PSModuleGraph() {
        $this.Nodes = @()
        $this.Edges = @()
        $this.Analysis = @{}
    }
}
