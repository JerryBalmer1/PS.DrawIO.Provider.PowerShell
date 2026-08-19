class PSModuleGraphNode {
    [string]$Id
    [string]$Type
    [string]$Name
    [string]$Visibility
    [string]$Path
    [object]$Extent
}

class PSModuleGraphEdge {
    [string]$From
    [string]$To
    [string]$Type
    [object]$Extent
}
