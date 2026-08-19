# Limitations

This provider performs static AST analysis. It cannot reliably determine functions created at runtime, dynamically constructed command names, conditional exports, or behavior hidden behind runtime version checks.

Those gaps are retained in `Analysis.Confidence` rather than silently omitted. Dynamic and otherwise unresolved invocations share the `Unresolved` bucket and are distinguished by `Kind`. `Unresolved` edges are evidence that a human review is needed, not proof that no dependency exists.

External command classification is static and environment-dependent. The provider can identify a built-in command when the current PowerShell session resolves it, identify a loaded module command, or report `Unknown`; it does not execute or import the target module to improve that result. External commands receive placeholder nodes so graph closure is preserved, but the placeholder is not a claim that the command's implementation is available.

Node paths are relative to the analysis root for portability. The root itself remains in `PSModuleGraph.RootPath`, so consumers can resolve source links without embedding absolute paths in every node.

v1 analyzes one source tree at a time. Cross-module dependency analysis and draw.io rendering belong to later modules or versions.
