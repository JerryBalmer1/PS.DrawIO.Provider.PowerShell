# PS.DrawIO.Provider.PowerShell

**The first provider. Its real job is to prove the contract works.**

This repository ships one module: `PS.DrawIO.Provider.PowerShell`. It analyzes PowerShell modules through static AST inspection and produces a structured model of what's inside them — functions, classes, enums, and the dependency relationships between them.

Read `REGISTRY.md` in the registry repository first. This module is a client of that contract and does not redefine it.

> **§9 of this document is executable.** The acceptance suite parses its checkboxes and keys tests by label text. Editing a checkbox changes the test suite. Adding one makes the meta-test fail until a matching `It` block exists. Treat edits here as code changes.

---

## 1. Two jobs, one module, hard wall between them

```
   ┌─────────────────────────────────────────────────────────┐
   │  DECLARATION HALF          small • static • rarely changes│
   │                                                           │
   │  "A PSFunction looks like rounded=1;fillColor=#DAE8FC;"   │
   │  "Public and private are variants of the same type"       │
   │  "Link template is vscode://file/{path}:{line}"           │
   │  "Functions that call each other should be near each other"│
   │                                                           │
   │  → registered with PS.DrawIO.Registry                     │
   └─────────────────────────────────────────────────────────┘
   ══════════════════ HARD WALL ══════════════════════════════
   ┌─────────────────────────────────────────────────────────┐
   │  EXTRACTION HALF           large • dynamic • the real work│
   │                                                           │
   │  Parse .psm1/.ps1/.psd1 → AST → domain model              │
   │  Resolve call graphs, aliases, class hierarchies          │
   │                                                           │
   │  → produces PSModuleGraph, a PowerShell-shaped object     │
   └─────────────────────────────────────────────────────────┘
```

**Why the wall matters.** The declaration half is what the registry contract covers. The extraction half is roughly ten times the code and touches none of it. If extraction logic leaks into declarations, the provider stops being a contract participant and becomes an application — and the registry's whole purpose evaporates.

Enforced structurally: declarations live in `src/Declarations/` and are **pure data**. No file in `src/Declarations/` may call anything in `src/Analysis/`.

---

## 2. What v1 does not do

**v1 does not produce a `.drawio` file.**

Producing a diagram requires XML emission, geometry, and layout. All three belong to `PS.DrawIO.Core`, which does not exist yet.

v1 output is a **`PSModuleGraph`**, serializable to JSON. v1.1 adds a thin adapter mapping that graph onto Core's IR.

The graph is safe to build now because **it describes PowerShell, not diagrams.** A function's name, visibility, parameters, and call edges are facts about the source. They don't change when Core decides how to lay out a box.

```
   v1                                    v1.1
   ┌──────────────┐                      ┌──────────────┐
   │ PSModuleGraph│                      │ PSModuleGraph│
   └──────┬───────┘                      └──────┬───────┘
          ▼                                     ▼
   ┌──────────────┐                      ┌──────────────┐
   │ JSON         │                      │ IR adapter   │──► Core ──► .drawio
   └──────────────┘                      └──────────────┘
```

---

## 3. Parse, never import

**Hard rule: this module never calls `Import-Module` on analysis targets.**

`Import-Module` executes the target's code. Analyzing an arbitrary module by importing it is an arbitrary-code-execution vector, and it mutates the caller's session.

`[System.Management.Automation.Language.Parser]::ParseFile()` reads source into an AST without executing anything. That is the only ingestion path.

### The honest cost

Static analysis cannot see functions created at runtime, conditional `Export-ModuleMember` logic, dynamically constructed command names, or anything behind version-dependent branching.

The graph **declares these limits in its own output**. Every `PSModuleGraph` carries an `Analysis.Confidence` block naming what could not be determined statically. A tool that silently omits what it can't see is worse than one that admits the gap.

---

## 4. The dependency graph is the risk surface

Naive name-matching misses aliases, dynamic invocation, `Invoke-Expression`, shadowed names, and names appearing in strings. Since this diagram exists to show risk, a wrong edge is worse than a missing one — it produces false confidence.

```
   CommandAst found
        │
        ▼
   ┌─────────────────────┐
   │ static command name?│──── no ──► Unresolved (record extent)
   └──────────┬──────────┘
              │ yes
              ▼
   ┌─────────────────────┐
   │ resolve aliases     │
   └──────────┬──────────┘
              ▼
   ┌─────────────────────┐
   │ in this module?     │──── no ──► External
   └──────────┬──────────┘             └─ BuiltIn / Module / Unknown
              │ yes
              ▼
          Internal                    ◄── the only high-confidence kind
```

`Unresolved` edges are retained and rendered, never dropped. External references subdivide further, because `ForEach-Object` and a third-party dependency carry completely different risk.

**Benign patterns are recognized, not reported.** The standard `.psm1` dot-source loader is mandated boilerplate. A confidence report that flags required patterns trains the reader to ignore it.

---

## 5. Analysis sessions, not module state

**Rejected: `$script:` scoped cache.** Persists across calls, survives until unload, makes tests order-dependent, cannot be parallelized.

**Adopted: an explicit session object the caller holds.**

```powershell
$session = New-PSDrawIOPSAnalysis -Path ./src
Get-PSDrawIOPSFunction   -Session $session
Get-PSDrawIOPSClass      -Session $session
Get-PSDrawIOPSDependency -Session $session   # reuses parsed ASTs
$graph = Build-PSDrawIOPSGraph -Session $session
```

No hidden state, disposable, parallel-safe, every helper a pure function of its session.

**Class identity caveat.** PowerShell class types are tied to the defining module's session state, so a `-Force` re-import invalidates casts against previously created objects. Public parameters therefore accept session objects **without a hard class cast**, while the session is still constructed as a typed `PSAnalysisSession`. The general rule — **classes internal, duck-typed at module boundaries** — is recorded in `docs/PATTERNS.md` and applies to every provider.

---

## 6. Graph schema invariants

These are load-bearing for Core and must not regress:

- **Closed graph.** Every edge endpoint resolves to a node `Id` present in the graph. External and unresolved references get placeholder nodes.
- **IDs, not names.** Edge `From`/`To` carry node `Id` values (`Function:Get-Thing`), never bare names — a bare name is ambiguous where a function and class share one.
- **Aggregated edges.** One edge per pair, carrying `CallCount` and an `Extents` array. Fidelity preserved without drawing parallel arrows.
- **Relative paths.** Node paths are relative to `RootPath`, recorded once. Absolute paths are non-portable and leak local structure.
- **Single confidence collection.** `Unresolved` with a `Kind` discriminator, not parallel buckets.

---

## 7. Feeding the scaffolder

`New-PSDrawIOProvider` is a Registry deliverable. This repository does not build a second scaffolder — it produces **evidence**.

```
   Provider.PowerShell ──► docs/PATTERNS.md ──► Registry's scaffolder
                                                       │
                                                       ▼
                                          Provider.Terraform starts better
                                                       │
                                          confirms or refutes ──► evidence-backed
```

`docs/PATTERNS.md` is a **living v1 deliverable**, updated during development. Written afterward it becomes fiction — nobody remembers which parts were painful once they're finished.

Two providers is the minimum to distinguish a real pattern from a PowerShell-shaped coincidence. Do not generalize from one.

---

## 8. Order of operations

```
   Registry v1 (contract frozen)
        │
        ▼
   THIS REPO v1        AST extraction → PSModuleGraph → JSON
                       declarations registered.  NO diagram.
        │
        ▼
   Core v1             IR + XML + layout
        │
        ▼
   THIS REPO v1.1      graph → IR adapter → .drawio
        │
        ▼
   Provider.Terraform  proves it generalizes
        │
        ▼
   Registry v1.x       scaffolder refined from evidence
```

---

## 9. Definition of Done — v1.0.0

> **This section drives the acceptance suite.** Every checkbox needs a matching `It` block in `tests/Acceptance/`. The meta-test enforces it. If an item is unchecked, v1 is not done. If it is not listed, it is not required for v1.

### Declaration half
- [x] Provider manifest declares `ContractVersion`, `ProviderName = 'PowerShell'`, and `Capabilities`
- [x] Registers successfully against `PS.DrawIO.Registry` v1
- [x] Passes `Test-PSDrawIOProviderConformance` with zero failures
- [x] Semantic types declared: `PSFunction`, `PSClass`, `PSEnum`, `PSModule`, plus edge types `Internal`, `External`, `Unresolved`, `Inherits`
- [ ] Node types and edge types are declared separately, not merged into one collection
- [x] Public/private expressed as **variants**, not separate types
- [x] Link template declared for `vscode://` source navigation
- [x] Layout **hints** only — zero geometry code in this repository
- [x] Nothing in `src/Declarations/` calls anything in `src/Analysis/` — enforced by a test

### Extraction half
- [x] `New-PSDrawIOPSAnalysis` builds a session from a path
- [x] **No code path calls `Import-Module` on an analysis target** — enforced by an AST-based test
- [x] Functions extracted: name, visibility, `CmdletBinding` + args, parameters, parameter sets, help presence, AST extent
- [x] Classes extracted: name, base type, properties, methods, inheritance edges
- [x] Enums extracted: name, underlying type, members
- [x] Dependencies classified as `Internal` / `External` / `Unresolved`
- [x] Aliases resolved before classification
- [x] `Unresolved` edges retained with source extent, never silently dropped
- [x] Every graph carries an `Analysis.Confidence` block
- [x] Benign dot-source loader boilerplate is not reported as a confidence concern
- [x] `Build-PSDrawIOPSGraph` produces a `PSModuleGraph`
- [x] Graph serializes to JSON and round-trips back to an equivalent object

### Graph schema
- [x] Every edge endpoint resolves to a node `Id` present in the graph
- [x] External and unresolved references have placeholder nodes
- [x] Duplicate edges aggregated with `CallCount` and `Extents`
- [x] External references classified as `BuiltIn` / `Module` / `Unknown`
- [x] Node paths stored relative to `RootPath`

### Proof
- [x] Analyzes **itself** end to end, and the result is correct on inspection
- [x] Analyzes `PS.DrawIO.Registry` end to end
- [x] Analyzes a fixture module containing deliberate alias use, dynamic invocation, and a parse error — all three appear correctly in confidence output
- [x] Analyzing a module with a **known malicious side effect in its top-level scope** does not execute it

### Quality gates
- [x] Pester 5 green on Windows and Linux — PowerShell 7+
- [x] Coverage ≥ 90% on `src/Analysis`, ≥ 80% overall
- [x] `PSScriptAnalyzer` clean at Error and Warning; suppressions justified inline
- [x] `Test-ModuleManifest` passes
- [x] Imports clean in a fresh session
- [x] Analysis of a 200-function module with realistic call density completes in under 30 seconds, measured
- [x] No `src/Public` function exceeds 100 lines
- [x] All exported names use approved verbs

### Documentation
- [x] `README.md` — install → analyze → inspect graph in under 20 lines
- [x] `docs/DOMAIN-MODEL.md` — the `PSModuleGraph` schema
- [x] `docs/PATTERNS.md` — **maintained during development**, feeds the registry scaffolder
- [x] `docs/LIMITATIONS.md` — what static analysis cannot see, stated plainly
- [x] `CHANGELOG.md` per Keep a Changelog

### Explicitly NOT in v1
- ✗ `.drawio` file output of any kind
- ✗ XML generation
- ✗ Layout algorithms or geometry
- ✗ Any dependency on `PS.DrawIO.Core`
- ✗ macOS testing — Windows and Linux only until hardware is available
- ✗ Repository tooling detection (PSScriptAnalyzer, Pester, CI) — v1.2
- ✗ Theme file contents beyond declared defaults
- ✗ A provider scaffolder — that is Registry's
- ✗ Cross-module analysis
- ✗ PSGallery publication

---

## 10. Repository layout

```
   PS.DrawIO.Provider.PowerShell/
   ├── src/
   │   ├── PS.DrawIO.Provider.PowerShell.psd1
   │   ├── Declarations/          pure data — shapes, hints, links, themes
   │   ├── Analysis/              AST work, private
   │   ├── Classes/               PSAnalysisSession, PSModuleGraph, nodes, edges
   │   ├── Public/                one function per file, exported
   │   ├── Private/               one function per file, internal
   │   └── en-US/
   ├── tests/
   │   ├── Unit/
   │   ├── Integration/
   │   ├── Acceptance/            one It per §9 checkbox + meta-test
   │   ├── Fixtures/              deliberately pathological modules
   │   └── Conformance/           registry-supplied suite
   ├── docs/
   │   ├── DOMAIN-MODEL.md
   │   ├── PATTERNS.md            ◄── living document
   │   ├── LIMITATIONS.md
   │   ├── SIGNOFF.json           manual sign-off, countersigned per commit
   │   └── DECISIONS/             ADRs, numbered, append-only
   ├── build/build.ps1
   ├── DoNotModify/               ◄── OFF LIMITS
   ├── AGENTS.md
   ├── README.md
   ├── CHANGELOG.md
   └── PROVIDER.md                this file
```

**Noun prefix is `PSDrawIOPS`** — `New-PSDrawIOPSAnalysis`, `Get-PSDrawIOPSFunction`, `Build-PSDrawIOPSGraph`. Applies to private functions too; `PSDrawIO` alone is the registry's namespace.

---

## 11. Testing constraints

Learned the hard way; both are in `AGENTS.md` and repeated here because violating either destroys a work session.

**Never `Invoke-Pester -CI` interactively.** `-CI` sets `Run.Exit`, terminating the host process on failure. Use `-PassThru` and inspect `FailedCount` and `Containers.Result`. `-CI` belongs only in the CI pipeline.

**Code for a `.ps1` goes in the file, never the prompt.** `$PSScriptRoot` is empty interactively and `BeforeAll` has no meaning outside a test file. Verify by running the file.

**Pester 5 discovery and run are separate scopes.** File-scope variables read inside `BeforeAll`/`It` need the `$script:` prefix or they arrive null.

**The build must detect both failure modes.** Assertion failures and containers that produced no tests are different problems. `$LASTEXITCODE` reflects neither — it is set by native executables, not cmdlets.
