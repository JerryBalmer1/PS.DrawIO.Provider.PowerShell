# ADR 0003: Keep Node and Edge Declarations in Registry v1 Shapes

## Status
Accepted for Provider v1

## Context
The provider's graph has node types such as `PSFunction`, `PSClass`, `PSEnum`, and `PSModule`, and edge types such as `Internal`, `External`, `Unresolved`, and `Inherits`. They are not interchangeable: nodes carry identity, variants, source links, and layout hints; edges carry relationship semantics, aggregation, and external classification. They therefore have different properties, validation needs, and rendering paths.

The new provider specification exposes this distinction as an acceptance requirement. Registry v1, however, defines `PrivateData.PSDrawIO.Shapes` as one opaque map of semantic type names to declaration data. Its parser validates that map but has no `NodeTypes` or `EdgeTypes` collections.

## Options considered

1. Keep the Registry v1 `Shapes` collection and retain the failing separate-declaration acceptance test as contract evidence.
2. Add provider-local `NodeTypes` and `EdgeTypes` metadata alongside `Shapes`, creating duplicated declarations and a compatibility interpretation future providers would inherit.
3. Change the Registry contract to define separate node and edge collections.

## Decision
Choose option 1. Do not add provider-local `NodeTypes` or `EdgeTypes`, and do not modify the Registry contract. The provider remains a faithful Registry v1 client. The acceptance failure is intentionally retained to record the contract limitation.

## Consequences
The current manifest has one source of truth and continues to conform to Registry v1. Consumers must distinguish node and edge semantics from the declared entries in `Shapes` until a future contract provides a first-class separation. The acceptance suite makes the limitation visible rather than silently encoding a provider-specific workaround.

Terraform is the next useful evidence source. If its resource nodes and dependency-reference edges exhibit the same property, validation, and rendering split, the Registry contract should be reconsidered with evidence from two providers. If Terraform does not, this may remain PowerShell-specific.
