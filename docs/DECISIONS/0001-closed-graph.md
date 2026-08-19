# ADR 0001: Keep Graphs Closed

## Status
Accepted

## Context
Dependency edges can reference commands outside the analyzed module. A graph containing an edge whose target has no node cannot be joined, rendered, or inspected reliably.

## Decision
Emit placeholder nodes for external and unresolved references. Edge endpoints always use node `Id` values. Placeholder nodes carry the reference name and classification, while source declarations retain their relative paths and extents.

## Consequences
Consumers can validate every edge endpoint and serialize a closed graph. The provider does not pretend to have analyzed external implementation details; placeholders make that boundary explicit. The decision is a reusable contract concern for future providers, not a PowerShell-only workaround.
