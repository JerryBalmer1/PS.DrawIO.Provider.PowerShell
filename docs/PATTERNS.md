# Patterns

The registry contract made the declaration half straightforward: semantic types, source links, and layout hints are opaque data and remain independent from AST extraction.

The provider keeps an explicit analysis session rather than module-scoped caches. This makes tests deterministic and lets callers serialize or retain multiple analyses safely.

PowerShell class types can be redefined during module reloads, so public helper parameters accept session objects without a brittle class cast. The session is still created as a typed `PSAnalysisSession`.
