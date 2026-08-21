# Changelog

All notable changes to this project will be documented here.

## [Unreleased]

## [1.0.0] - 2026-08-21

- Added the PowerShell AST provider and serializable module graph.
- Added static function, class, enum, and dependency extraction.
- Added confidence reporting for parse errors and dynamic invocations.
- Added closed, ID-addressed graphs with external placeholders, edge aggregation, and portable node paths.
- Added acceptance coverage and documented provider contract findings.
- Node types and edge types remain declared in one Shapes collection — the separate-collections DoD item ships unmet, blocked on a registry contract major (see docs/DECISIONS/0003-node-edge-declaration-contract.md and PS.DrawIO.Registry ADR 0002).
