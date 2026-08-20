# Domain Model

`PSModuleGraph` is the v1 output. It contains:

- `Path`: analyzed file or directory. `RootPath` records the single analysis root.
- `Nodes`: `PSFunction`, `PSClass`, and `PSEnum` source declarations with names, paths, and AST extents. Node paths are relative to `RootPath`. External commands are represented by `PSExternalCommand` placeholder nodes, and unresolved invocations by `PSUnresolved` placeholder nodes, so every edge endpoint is present in `Nodes`.

  **Node `Visibility`** (on source declaration nodes such as `PSFunction`) is one of:

  | Value | Meaning |
  |---|---|
  | `Public` | Defined outside `Private/` and outside the non-exported analysis directory (typical export surface). |
  | `Private` | Defined under a `Private/` path (module-internal helpers). |
  | `Internal` | Defined under a non-exported analysis directory (`src/Analysis/`). Neither a Public nor Private export variant. |

  Node `Visibility` `Internal` and edge classification `Internal` are **unrelated** tokens that share a name only. Node visibility describes where a declaration lives in the module layout. Edge `Internal` means a call target resolved to another declaration inside the analyzed module. Do not treat them as the same concept.

- `Edges`: dependency records classified as `Internal`, `External`, or `Unresolved`. `From` and `To` always contain node `Id` values, never display names. Duplicate calls are one edge with `CallCount` and an `Extents` array. External edges also carry `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`.
- `Analysis.Confidence`: `ParseErrors` and one `Unresolved` collection. Each unresolved finding has a `Kind` discriminator such as `DynamicInvocation` or `UnresolvedInvocation`; benign dot-source loader commands are excluded.

The graph is plain PowerShell data and can be serialized with `ConvertTo-Json -Depth 20`. It contains no draw.io XML or geometry.
