# Patterns

The registry contract made the declaration half straightforward: semantic types, source links, and layout hints are opaque data and remain independent from AST extraction.

The provider keeps an explicit analysis session rather than module-scoped caches. This makes tests deterministic and lets callers serialize or retain multiple analyses safely.

PowerShell class types can be redefined during module reloads, so public helper parameters accept session objects without a brittle class cast. The session is still created as a typed `PSAnalysisSession`.

## Findings for the registry contract

Graph closure is a contract-level question, not a PowerShell-only extraction detail. A provider needs a way to represent referenced entities that it cannot declare locally; placeholder nodes keep every edge joinable and make that expectation reusable by other providers.

External-reference classification also recurs across providers. PowerShell uses `BuiltIn`, `Module`, and `Unknown`, while another provider may use different categories, but the shape is the same: an external edge needs a provider-defined taxonomy and a stable fallback for unknown resolution.

Confidence reporting was provider-local because AST extents, dynamic invocation, and dot-source boilerplate are PowerShell-specific signals. The contract should model the existence of confidence findings and their source evidence, while each provider supplies its finding kinds.

The `Internal` / `External` / `Unresolved` split felt universal: it describes whether a reference joins locally, resolves outside the analyzed unit, or cannot be statically resolved. Alias resolution and the benign dot-source exception were PowerShell-specific implementation details.

The "hints, never geometry" boundary held. Group and direction hints were enough for declarations; reaching for placement would have coupled this provider to a renderer and violated the provider/registry/core split.

Visibility as a variant worked cleanly. `Public` and `Private` describe the same semantic function shape, so variants avoid duplicating contract types while the extractor remains free to derive visibility from provider source conventions.

### Contract defect: node and edge declarations

The provider exposed a concrete contract limitation: node types and edge types have different properties, different validation needs, and different rendering paths, but Registry v1 models both as entries in one opaque `Shapes` collection. The resulting acceptance finding is not missing provider work; adding `NodeTypes` and `EdgeTypes` locally would duplicate declarations and create a second source of truth beside `Shapes`.

Option 1 is therefore retained: keep the Registry v1 `Shapes` collection and leave the separate-declaration acceptance test failing as evidence. A provider-local compatibility layer or a Registry contract change would both need broader evidence. Terraform is likely to encounter the same shape of problem with resource nodes versus dependency-reference edges; its experience should confirm or refute this finding before the contract moves.
