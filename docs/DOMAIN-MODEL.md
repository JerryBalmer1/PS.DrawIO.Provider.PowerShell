# Domain Model

`PSModuleGraph` is the v1 output. It contains:

- `Path`: analyzed file or directory. `RootPath` records the single analysis root.
- `Nodes`: `PSFunction`, `PSClass`, and `PSEnum` source declarations with names, paths, and AST extents. Node paths are relative to `RootPath`. External commands are represented by `PSExternalCommand` placeholder nodes, and unresolved invocations by `PSUnresolved` placeholder nodes, so every edge endpoint is present in `Nodes`.
- `Edges`: dependency records classified as `Internal`, `External`, or `Unresolved`. `From` and `To` always contain node `Id` values, never display names. Duplicate calls are one edge with `CallCount` and an `Extents` array. External edges also carry `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`.
- `Analysis.Confidence`: `ParseErrors` and one `Unresolved` collection. Each unresolved finding has a `Kind` discriminator such as `DynamicInvocation` or `UnresolvedInvocation`; benign dot-source loader commands are excluded.

The graph is plain PowerShell data and can be serialized with `ConvertTo-Json -Depth 20`. It contains no draw.io XML or geometry.
