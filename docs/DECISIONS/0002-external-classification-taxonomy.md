# ADR 0002: Classify External References

## Status
Accepted

## Context
External references are not equally informative. Built-in commands are common diagram noise, module-provided commands have a different review path, and unresolved command lookup must remain visible without being misclassified.

## Decision
Every external edge carries `ExternalKind`: `BuiltIn`, `Module`, or `Unknown`. Classification uses static command metadata available to the analyzing session. Unknown is the stable fallback when metadata is absent or ambiguous.

## Consequences
Consumers can filter routine built-in edges while preserving module and unknown risk signals. The category names are PowerShell-specific, but the contract pattern is universal: providers need a taxonomy plus an explicit unknown bucket for external references.
