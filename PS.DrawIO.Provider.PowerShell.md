# PS.DrawIO.Provider.PowerShell

**The first provider. Its real job is to prove the contract works.**

This repository ships one module: `PS.DrawIO.Provider.PowerShell`. It analyzes PowerShell modules through static AST inspection and produces a structured model of what's inside them — functions, classes, enums, and the dependency relationships between them.

Read [`REGISTRY.md`](../PS.DrawIO.Registry/REGISTRY.md) in the registry repository first. This module is a client of that contract and does not redefine it.

---

## 1. Two jobs, one module, hard wall between them

This provider does two things that are easy to conflate and must not be:

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

**Why the wall matters.** The declaration half is what the registry contract covers. The extraction half is ten times the code and touches none of it. If extraction logic leaks into declarations, the provider stops being a contract participant and becomes an application — and the registry's whole purpose evaporates.

Enforced structurally: declarations live in `src/Declarations/` and are **pure data**. No function in `src/Declarations/` may call anything in `src/Analysis/`.

---

## 2. What v1 does not do

**v1 does not produce a `.drawio` file.**

This is deliberate and it is the most important scoping decision in this repository.

Producing a diagram requires XML emission, geometry, and layout. All three belong to `PS.DrawIO.Core`, which does not exist yet. `REGISTRY.md` §8 explicitly forbids depending on it.

The options were:

| Option | Verdict |
|---|---|
| Write a throwaway XML emitter here | ✗ Throwaway emitters become permanent. Two XML paths forever. |
| Wait for Core before starting | ✗ Wastes the independent work — AST extraction owes Core nothing |
| **Ship the domain model, defer rendering** | ✓ |

So v1 output is a **`PSModuleGraph`** object, serializable to JSON. v1.1 adds a thin adapter mapping that graph onto Core's IR.

The graph is safe to build now because **it describes PowerShell, not diagrams.** A function's name, visibility, parameters, and call edges are facts about the source. They don't change when Core decides how to lay out a box.

```
   v1                                    v1.1
   ┌──────────────┐                      ┌──────────────┐
   │ PSModuleGraph│                      │ PSModuleGraph│
   └──────┬───────┘                      └──────┬───────┘
          │                                     │
          ▼                                     ▼
   ┌──────────────┐                      ┌──────────────┐
   │ JSON         │                      │ IR adapter   │──► Core ──► .drawio
   └──────────────┘                      └──────────────┘
                                                │
                                                └─► JSON still works
```

---

## 3. Parse, never import

**Hard rule: this module never calls `Import-Module` on analysis targets.**

`Import-Module` executes the target's code. Analyzing an arbitrary module by importing it is an arbitrary-code-execution vector, and it mutates the caller's session. Neither is acceptable in a tool whose entire job is inspection.

`[System.Management.Automation.Language.Parser]::ParseFile()` reads source into an AST without executing anything. That is the only ingestion path.

### The honest cost

Static analysis cannot see:

- Functions created at runtime (`New-Item function:`, `Invoke-Expression`)
- Conditional `Export-ModuleMember` logic
- Dynamically constructed command names
- Anything behind `$PSVersionTable`-dependent branching

The graph must **declare these limits in its own output**, not hide them. Every `PSModuleGraph` carries an `Analysis.Confidence` block naming what could not be determined statically. A tool that silently omits what it can't see is worse than one that admits the gap.

---

## 4. The dependency graph is the risk surface

The headline feature — showing which functions depend on which — is also the easiest thing to get subtly, confidently wrong.

Naive approach: collect function names, walk each function's AST for `CommandAst`, match names against the list.

That misses:

| Case | Example | Consequence |
|---|---|---|
| Aliases | `gci` → `Get-ChildItem` | edge dropped |
| Dynamic invocation | `& $commandName` | edge dropped |
| `Invoke-Expression` | `iex $code` | edge dropped, silently |
| Shadowed names | local `Get-Thing` vs. imported | **wrong edge drawn** |
| Names in strings | `"call Get-Thing"` | **false edge drawn** |
| Splatted command names | `& $cmd @params` | edge dropped |

Since this diagram is explicitly meant to show risk to the end user, a wrong edge is worse than a missing one — it produces false confidence.

### Required handling

```
   CommandAst found
        │
        ▼
   ┌─────────────────────┐
   │ static command name?│──── no ──► edge type: Unresolved
   └──────────┬──────────┘             record the AST extent
              │ yes                    so a human can look
              ▼
   ┌─────────────────────┐
   │ resolve aliases      │
   └──────────┬──────────┘
              ▼
   ┌─────────────────────┐
   │ in this module?      │──── no ──► edge type: External
   └──────────┬──────────┘
              │ yes
              ▼
        edge type: Internal          ◄── the only high-confidence kind
```

Three edge types, each carrying confidence. `Unresolved` edges are rendered, not dropped — a visible "something happens here we couldn't trace" is useful information.

---

## 5. Analysis sessions, not module state

You need caching. A module analyzed once shouldn't be re-parsed by every helper.

**Rejected: `$script:` scoped cache.** It persists across calls, survives until module unload, makes test outcomes order-dependent, and cannot be parallelized. This is a well-known PowerShell footgun and it is not worth the small convenience.

**Adopted: an explicit session object the caller holds.**

```powershell
$session = New-PSDrawIOPSAnalysis -Path ./src
Get-PSDrawIOPSFunction   -Session $session
Get-PSDrawIOPSClass      -Session $session
Get-PSDrawIOPSDependency -Session $session   # reuses parsed ASTs
$graph = Build-PSDrawIOPSGraph -Session $session
```

```
   ┌────────────────────────────────────────────┐
   │  PSAnalysisSession        (class instance) │
   │                                            │
   │  Files      [] parsed once                 │
   │  Asts       {} cached by path              │
   │  Functions  [] resolved once               │
   │  Confidence {} accumulated warnings        │
   └────────────────────────────────────────────┘
              ▲              ▲              ▲
              │              │              │
        Get-Function   Get-Class    Get-Dependency
        (pure, takes session, returns data)
```

Properties: no hidden state, disposable, parallel-safe, and every helper is a pure function of its session. Tests construct a session from fixtures and assert — no import, no cleanup, no ordering.

---

## 6. What gets extracted

### Functions
- Name, and whether it resolves as **public or private** (dot-sourced location, `Export-ModuleMember`, manifest `FunctionsToExport`)
- `[CmdletBinding()]` present, and its arguments (`SupportsShouldProcess`, `DefaultParameterSetName`)
- Parameters: name, type, mandatory, parameter sets, pipeline binding
- Comment-based help present or absent
- Line count and AST extent, for the source link
- Output type, where declared

### Classes
- Name, base type, whether it's exported
- Properties: name, type, static, hidden
- Methods: name, signature, static, hidden
- Inheritance edges between classes in the same module

### Enums
- Name, underlying type, members and values

### Dependencies
- Internal, External, Unresolved (per §4)
- Class-to-class inheritance
- Function-to-class instantiation

### Confidence
- Files that failed to parse, with the parse error
- Unresolved dynamic invocations, with source extent
- Anything the manifest claims to export that wasn't found

---

## 7. Feeding the scaffolder — the real secondary goal

You want each new provider to be easier than the last. The mechanism is **not** building a scaffolder here — `New-PSDrawIOProvider` is already a Registry v1 deliverable, and a second one creates two sources of truth.

Instead this repository produces **evidence**:

```
   PS.DrawIO.Provider.PowerShell
        │
        │  docs/PATTERNS.md   ◄── written as we go, not retrofitted
        │  • what the contract made easy
        │  • what it made awkward
        │  • what every provider will need
        │  • what was PowerShell-specific
        ▼
   PS.DrawIO.Registry
        └─ New-PSDrawIOProvider improved from real experience
                │
                ▼
        PS.DrawIO.Provider.Terraform     starts from a better scaffold
                │
                │  docs/PATTERNS.md      confirms or refutes
                ▼
        the pattern is now evidence-backed, not guessed
```

`docs/PATTERNS.md` is a **living v1 deliverable**, updated during development. Written after the fact it becomes fiction — nobody remembers which parts were painful once they're finished.

Two providers is the minimum to distinguish a real pattern from a PowerShell-shaped coincidence. Do not generalize from one.

---

## 8. Order of operations

```
   ┌──────────────────────────────────────────────────────────┐
   │ PS.DrawIO.Registry v1        contract frozen              │
   └────────────────────────┬─────────────────────────────────┘
                            │ blocks
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ THIS REPO v1                                              │
   │   AST extraction → PSModuleGraph → JSON                   │
   │   declarations registered                                 │
   │   NO diagram output                                       │
   └────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ PS.DrawIO.Core v1            IR + XML + layout            │
   └────────────────────────┬─────────────────────────────────┘
                            │ unblocks
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ THIS REPO v1.1               graph → IR adapter → .drawio │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ PS.DrawIO.Provider.Terraform  proves it generalizes       │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ PS.DrawIO.Registry v1.x       scaffolder from evidence    │
   └──────────────────────────────────────────────────────────┘
```

Nothing in this repository begins before the registry contract is frozen. Building against a moving contract is how the root principle gets violated on day one.

---

## 9. Definition of Done — v1.0.0

> If an item is unchecked, v1 is not done. If it is not listed, it is not required for v1.

### Declaration half
- [ ] Provider manifest declares `ContractVersion`, `ProviderName = 'PowerShell'`, and `Capabilities`
- [ ] Registers successfully against `PS.DrawIO.Registry` v1
- [ ] Passes `Test-PSDrawIOProviderConformance` with zero failures
- [ ] Semantic types declared: `PSFunction`, `PSClass`, `PSEnum`, `PSModule`, plus edge types `Internal`, `External`, `Unresolved`, `Inherits`
- [ ] Public/private expressed as **variants**, not separate types
- [ ] Link template declared for `vscode://` source navigation
- [ ] Layout **hints** only — zero geometry code in this repository
- [ ] Nothing in `src/Declarations/` calls anything in `src/Analysis/` — enforced by a test

### Extraction half
- [ ] `New-PSDrawIOPSAnalysis` builds a session from a path
- [ ] **No code path calls `Import-Module` on an analysis target** — enforced by a test
- [ ] Functions extracted: name, visibility, `CmdletBinding` + args, parameters, parameter sets, help presence, AST extent
- [ ] Classes extracted: name, base type, properties, methods, inheritance edges
- [ ] Enums extracted: name, underlying type, members
- [ ] Dependencies classified as `Internal` / `External` / `Unresolved`
- [ ] Aliases resolved before classification
- [ ] `Unresolved` edges retained with source extent, never silently dropped
- [ ] Every graph carries an `Analysis.Confidence` block
- [ ] `Build-PSDrawIOPSGraph` produces a `PSModuleGraph`
- [ ] Graph serializes to JSON and round-trips back to an equivalent object

### Proof
- [ ] Analyzes **itself** end to end, and the result is correct on inspection
- [ ] Analyzes `PS.DrawIO.Registry` end to end
- [ ] Analyzes a fixture module containing deliberate alias use, dynamic invocation, and a parse error — all three appear correctly in confidence output
- [ ] Analyzing a module with a **known malicious side effect in its top-level scope** does not execute it

### Quality gates
- [ ] Pester 5 green on Windows, Linux, macOS — PowerShell 7+
- [ ] Coverage ≥ 90% on `src/Public`, ≥ 80% overall
- [ ] `PSScriptAnalyzer` clean at Error and Warning; suppressions justified inline
- [ ] `Test-ModuleManifest` passes
- [ ] Imports clean in a fresh session
- [ ] Analysis of a 200-function module completes in under 30 seconds
- [ ] No `src/Public` function exceeds 100 lines
- [ ] All exported names use approved verbs

### Documentation
- [ ] `README.md` — install → analyze → inspect graph in under 20 lines
- [ ] `docs/DOMAIN-MODEL.md` — the `PSModuleGraph` schema
- [ ] `docs/PATTERNS.md` — **maintained during development**, feeds the registry scaffolder
- [ ] `docs/LIMITATIONS.md` — what static analysis cannot see, stated plainly
- [ ] `CHANGELOG.md` per Keep a Changelog

### Explicitly NOT in v1
- ✗ `.drawio` file output of any kind
- ✗ XML generation
- ✗ Layout algorithms or geometry
- ✗ Any dependency on `PS.DrawIO.Core`
- ✗ Repository tooling detection (PSScriptAnalyzer, Pester, CI) — v1.2
- ✗ Theme file contents beyond declared defaults
- ✗ A provider scaffolder — that is Registry's
- ✗ Cross-module analysis (analyzing dependencies *between* modules)
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
   │   ├── Unit/                  mirrors src/
   │   ├── Integration/           self-analysis, registry analysis
   │   ├── Fixtures/              deliberately pathological modules
   │   └── Conformance/           registry-supplied suite
   ├── docs/
   │   ├── DOMAIN-MODEL.md
   │   ├── PATTERNS.md            ◄── living document
   │   ├── LIMITATIONS.md
   │   └── DECISIONS/
   ├── build/build.ps1
   ├── DoNotModify/               ◄── OFF LIMITS
   ├── AGENTS.md
   ├── README.md
   ├── CHANGELOG.md
   └── PROVIDER.md                this file
```

**Noun prefix is `PSDrawIOPS`** — `New-PSDrawIOPSAnalysis`, `Get-PSDrawIOPSFunction`, `Build-PSDrawIOPSGraph`. Awkward but unambiguous, and it prevents collision with the registry's `PSDrawIO` prefix. Confirm before the public surface freezes; renaming after v1 is a breaking change.

`tests/Fixtures/` must include modules that are deliberately bad: unparseable files, alias-heavy code, dynamic invocation, manifests claiming exports that don't exist, and a module whose top-level scope would write a file if executed. That last one is the test that proves parse-never-import holds.