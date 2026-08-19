# Limitations

This provider performs static AST analysis. It cannot reliably determine functions created at runtime, dynamically constructed command names, conditional exports, or behavior hidden behind runtime version checks.

Those gaps are retained in `Analysis.Confidence` rather than silently omitted. `Unresolved` edges are evidence that a human review is needed, not proof that no dependency exists.

v1 analyzes one source tree at a time. Cross-module dependency analysis and draw.io rendering belong to later modules or versions.
