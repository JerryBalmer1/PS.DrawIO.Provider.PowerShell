# Domain Model

`PSModuleGraph` is the v1 output. It contains:

- `Path`: analyzed file or directory.
- `Nodes`: `PSFunction`, `PSClass`, and `PSEnum` source declarations with names, paths, and AST extents.
- `Edges`: dependency records classified as `Internal`, `External`, or `Unresolved`.
- `Analysis.Confidence`: categorized `ParseErrors`, `Unresolved`, and `Dynamic` findings.

The graph is plain PowerShell data and can be serialized with `ConvertTo-Json -Depth 20`. It contains no draw.io XML or geometry.
