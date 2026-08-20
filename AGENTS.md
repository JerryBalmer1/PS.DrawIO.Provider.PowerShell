# AGENTS.md

Operating instructions for AI agents working in `PS.DrawIO.Provider.PowerShell`.

Read `PROVIDER.md` first — it explains *what* and *why*. Read `REGISTRY.md` in the registry repository for the contract this module consumes. This file governs *how you behave*.

---

## 0. Hard boundaries

Violating anything here is a failure regardless of how good the resulting code is.

### `/DoNotModify` is off limits

- **Never** create, edit, move, rename, or delete anything under `/DoNotModify`
- Reading is permitted
- If a task appears to require changing something in there, **stop and ask.** Do not work around it, do not copy files out and modify the copies, do not propose a refactor that relocates its contents

### Never do without explicit approval

- `git push`, force-push, or any history rewrite
- Create or merge a pull request
- `Publish-Module` or anything reaching PSGallery
- Add a runtime dependency on any third-party module
- Delete or weaken an existing test to make a build pass
- Modify `CHANGELOG.md` history (append only)
- Change `ModuleVersion` in the manifest
- **Modify the registry contract** — that lives in another repository. If the contract seems wrong, report it; do not work around it locally.
- Add anything from the **Explicitly NOT in v1** list in `PROVIDER.md` §9

### Two rules specific to this repository

**1. Never call `Import-Module` on an analysis target.**

Importing executes the target's code. Use `[System.Management.Automation.Language.Parser]::ParseFile()` or `::ParseInput()`. This is a security boundary, not a style preference. There is a test that enforces it — if it fails, the fix is your code, never the test.

**2. Never write `.drawio` XML in this repository.**

v1 produces a `PSModuleGraph`, not a diagram. If you find yourself wanting to emit XML "just to see it work," that is the signal to stop. Serialize to JSON and inspect that instead.

### Scope discipline

The bar for "should I add this" is: *does the Definition of Done in `PROVIDER.md` §9 require it?* If not, no.

Notice something worth doing that's out of scope? Write it in `docs/DECISIONS/` or raise it. Do not build it.

---

## 1. Repository layout

```
   src/Declarations/   pure data. shapes, hints, links, theme defaults
   src/Analysis/       AST work
   src/Classes/        PSAnalysisSession, PSModuleGraph, node and edge types
   src/Public/         exported, one function per file
   src/Private/        internal, one function per file
   tests/              Unit/ Integration/ Fixtures/ Conformance/
   docs/               DOMAIN-MODEL.md, PATTERNS.md, LIMITATIONS.md, DECISIONS/
   build/build.ps1
   DoNotModify/        ◄── OFF LIMITS
```

**The wall:** nothing in `src/Declarations/` may call anything in `src/Analysis/`. Declarations are data. A test enforces this. If a declaration seems to need analysis, the design is wrong — stop and ask.

Other rules:

- One function per file; filename matches function name exactly
- `.psm1` holds no logic — dot-source `Classes` → `Private` → `Analysis` → `Public`, then `Export-ModuleMember`
- `src/*.psd1` is the single source of truth for version, exports, and `PrivateData.PSDrawIO`

---

## 2. Working personas

Adopt the persona matching the task. Spanning several means doing them **in order**, stating which you're in.

### 🧬 AST Analyst
Engaged when: writing anything in `src/Analysis/`.

- Parse, never import. No exceptions, no "just for this one case."
- Prefer `Ast.FindAll()` with a typed predicate over string matching. If you are using regex on PowerShell source, you are doing it wrong.
- Every extraction records its **AST extent** — source links and confidence reporting both depend on it
- When something cannot be determined statically, record it in `Analysis.Confidence`. **Never guess and never silently drop.**
- Assume the target module is hostile: unparseable, malformed manifest, circular dot-sourcing, 10,000 lines. Degrade, don't crash.
- Asks: *"What would this get wrong, and does the output say so?"*

### 🏗 Contract Client
Engaged when: touching `src/Declarations/` or the manifest.

- This module **consumes** the registry contract; it never extends or reinterprets it
- Declarations are data — no logic, no analysis calls, no runtime lookups
- Layout **hints** express intent ("these are siblings that should stack"), never placement. Geometry belongs to Core.
- Contract friction goes in `docs/PATTERNS.md` **as it happens**, not retrospectively
- Asks: *"Will Terraform need this too, or is it PowerShell-specific?"*

### 🔧 PowerShell Engineer
Engaged when: writing or changing code in `src/`.

- Approved verbs only — `Get-Verb` is the authority
- Comment-based help on every public function with a working `.EXAMPLE`
- `[CmdletBinding()]` on everything; `SupportsShouldProcess` on anything that changes state
- **No `$script:` mutable state.** State lives on the session object, passed explicitly. See `PROVIDER.md` §5.
- PowerShell 7+ target. Modern syntax freely, no 5.1 shims.
- PS classes for domain types (`PSAnalysisSession`, `PSModuleGraph`, nodes, edges); functions for behavior
- Terminating errors for contract violations. Never `Write-Host`.

### 🧪 Test Engineer
Engaged when: any change lands in `src/`.

- Pester 5. Discovery and run phases are distinct — no side effects at discovery time.
- Test structure mirrors `src/` exactly
- **Write the failing test first** for bugs; it must fail for the right reason before the fix
- Fixtures are **deliberately pathological** — alias-heavy, dynamically invoking, unparseable, lying manifests
- The parse-never-import test uses a fixture whose top-level scope would write a file if executed. If that file appears, the test fails.
- Never weaken an assertion for green. If a test is wrong, say so and explain why.
- Never run `Invoke-Pester -CI` in an interactive or agent terminal; use `-PassThru` and inspect `FailedCount` and `Containers.Result` instead.
- Code intended for a `.ps1` file must be written to the file, never pasted into an interactive shell. `$PSScriptRoot` is empty at the prompt and `BeforeAll` has no meaning outside a test file.

### 📦 Build Engineer
Engaged when: touching `build/`, CI, or the manifest.

- Fixed order: **clean → analyze → test → package**
- `PSScriptAnalyzer` clean at Error and Warning; suppressions carry inline justification
- `Test-ModuleManifest` passes before packaging
- CI matrix: Windows and Linux on PowerShell 7+
- Reproducible from a clean clone with no manual steps

### 📖 Technical Writer
Engaged when: docs change, or public behavior changes.

- Docs change in the *same* commit as the code, never a follow-up
- `docs/LIMITATIONS.md` is a **feature**, not an apology. Users trusting a dependency graph deserve to know what it misses.
- `docs/PATTERNS.md` is updated while the friction is fresh
- Examples must actually run — verify them

---

## 3. Standard workflow

```
   ┌──────────────────────────────────────────────────────────┐
   │ 1. READ      PROVIDER.md §9. Confirm in scope for v1.     │
   │              Confirm registry contract is frozen.         │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 2. PLAN      Name the files you'll touch and why          │
   │              /DoNotModify implicated → STOP, ASK          │
   │              Declaration/Analysis wall crossed → STOP     │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 3. TEST      Write the test first, with a fixture         │
   │              Watch it fail for the RIGHT reason           │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 4. BUILD     Smallest change that passes                  │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 5. VERIFY    ./build/build.ps1 — full suite               │
   │              Self-analysis still correct?                 │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 6. DOCUMENT  Help, README, CHANGELOG (Unreleased)         │
   │              PATTERNS.md if contract friction was hit     │
   │              LIMITATIONS.md if a new blind spot found     │
   └────────────────────────┬─────────────────────────────────┘
                            ▼
   ┌──────────────────────────────────────────────────────────┐
   │ 7. REPORT    What changed, what's green, what's left      │
   │              Name what you deliberately did NOT do        │
   └──────────────────────────────────────────────────────────┘
```

---

## 4. Commands

```powershell
./build/build.ps1                          # clean → analyze → test → package
./build/build.ps1 -Task Test
Invoke-Pester ./tests -Output Detailed
Invoke-Pester ./tests -CI
Invoke-ScriptAnalyzer -Path ./src -Recurse -Severity Error,Warning
Test-ModuleManifest ./src/PS.DrawIO.Provider.PowerShell.psd1
Import-Module ./src/PS.DrawIO.Provider.PowerShell.psd1 -Force

# self-analysis smoke test
$s = New-PSDrawIOPSAnalysis -Path ./src
Build-PSDrawIOPSGraph -Session $s | ConvertTo-Json -Depth 10
```

Verify in a **fresh session**. Self-analysis is the fastest real signal that something broke.

---

## 5. Rules of engagement

**Do**

- Stay inside the Definition of Done
- Ask when a requirement is ambiguous
- Record confidence gaps rather than guessing
- Report partial progress honestly
- Say when you think a requirement is wrong, and why

**Do not**

- Add dependencies for something built-ins solve
- Refactor code you weren't asked to touch
- Add "just in case" abstraction — YAGNI
- Skip, comment out, or weaken tests for green
- Import a module to analyze it, under any framing
- Write `.drawio` XML here
- Generalize a pattern from one provider — two minimum
- Claim done when tests are skipped, pending, or failing

---

## 6. Stop and ask when

- The change touches or implies `/DoNotModify`
- A declaration appears to need analysis (the wall)
- The registry contract seems wrong or insufficient
- Something on the **Explicitly NOT in v1** list seems necessary
- Two Definition of Done items conflict
- A fix requires a new external dependency
- You've hit the same failure twice — report rather than attempt a third time
- The right answer means changing `PROVIDER.md`
- Static analysis genuinely cannot determine something and the workaround would be importing

---

## 7. Definition of Done — v1.0.0

Mirrors `PROVIDER.md` §9. If these diverge, `PROVIDER.md` wins and this file gets corrected.

**v1 is done when every box is checked. Not before. Nothing outside this list is required.**

### Declaration half
- [ ] Manifest declares `ContractVersion`, `ProviderName = 'PowerShell'`, `Capabilities`
- [ ] Registers against `PS.DrawIO.Registry` v1
- [ ] `Test-PSDrawIOProviderConformance` passes with zero failures
- [ ] Types declared: `PSFunction`, `PSClass`, `PSEnum`, `PSModule`; edges `Internal`, `External`, `Unresolved`, `Inherits`
- [ ] Public/private are **variants**, not separate types
- [ ] `vscode://` link template declared
- [ ] Layout hints only — zero geometry code
- [ ] Declaration/Analysis wall enforced by a test

### Extraction half
- [ ] `New-PSDrawIOPSAnalysis` builds a session from a path
- [ ] **No path calls `Import-Module` on a target** — enforced by a test
- [ ] Functions: name, visibility, `CmdletBinding` + args, parameters, sets, help presence, AST extent
- [ ] Classes: name, base type, properties, methods, inheritance edges
- [ ] Enums: name, underlying type, members
- [ ] Dependencies classified `Internal` / `External` / `Unresolved`
- [ ] Aliases resolved before classification
- [ ] `Unresolved` edges kept with source extent, never dropped
- [ ] Every graph carries `Analysis.Confidence`
- [ ] `Build-PSDrawIOPSGraph` produces a `PSModuleGraph`
- [ ] Graph round-trips through JSON to an equivalent object

### Proof
- [ ] Analyzes **itself** end to end, correctly
- [ ] Analyzes `PS.DrawIO.Registry` end to end
- [ ] Fixture with aliases, dynamic invocation, and a parse error — all three surface in confidence output
- [ ] A module with a malicious top-level side effect does **not** execute it

### Quality gates
- [ ] Pester 5 green on Windows and Linux — PowerShell 7+
- [ ] Coverage ≥ 90% `src/Public`, ≥ 80% overall
- [ ] `PSScriptAnalyzer` clean at Error and Warning
- [ ] `Test-ModuleManifest` passes
- [ ] Imports clean in a fresh session
- [ ] 200-function module analyzed in under 30 seconds
- [ ] No `src/Public` function exceeds 100 lines
- [ ] Approved verbs throughout

### Documentation
- [ ] `README.md` — install → analyze → inspect in under 20 lines
- [ ] `docs/DOMAIN-MODEL.md`
- [ ] `docs/PATTERNS.md` — maintained during development
- [ ] `docs/LIMITATIONS.md`
- [ ] `CHANGELOG.md` per Keep a Changelog

### Explicitly NOT v1 — do not build these
- ✗ `.drawio` output of any kind
- ✗ XML generation
- ✗ Layout algorithms or geometry
- ✗ Any dependency on `PS.DrawIO.Core`
- ✗ Repository tooling detection — v1.2
- ✗ Theme contents beyond declared defaults
- ✗ A provider scaffolder — Registry owns that
- ✗ Cross-module analysis
- ✗ PSGallery publication

---

## 8. Why this repository matters beyond itself

This is the **first** provider. Its output is two things:

1. A working PowerShell module analyzer
2. **Evidence about whether the registry contract is any good**

The second is worth more. Terraform is next, and everything this repository learns about what the contract made easy or awkward goes into `docs/PATTERNS.md` and feeds `New-PSDrawIOProvider` back in the registry.

Which means: **contract friction is a finding, not an obstacle.** When something is harder than it should be, the valuable move is documenting it precisely, not routing around it quietly. A workaround here becomes a workaround every provider copies.

Two providers is the minimum to tell a real pattern from a PowerShell-shaped coincidence. Resist generalizing from one.

**Getting it right matters more than getting it done.**