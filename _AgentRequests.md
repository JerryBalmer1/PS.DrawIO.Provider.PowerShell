# Agent request — Public/Analysis split + real wall test

**HEAD (unchanged):** `40f30aa` bug fixes  
**Status:** COMPLETE (uncommitted). No push, no SIGNOFF, no PROVIDER checkbox edits.

---

## 1. Inventory (pre-split → post-split)

| Public function | Pre lines (approx) | What moved | Analysis target |
|---|---|---|---|
| `New-PSDrawIOPSAnalysis` | ~39 | Parse files, build session, confidence | `Initialize-PSDrawIOPSAnalysis` |
| `Get-PSDrawIOPSFunction` | ~61 | Full AST function extraction | `Find-PSDrawIOPSFunction` |
| `Get-PSDrawIOPSClass` | ~24 | Class AST extraction | `Find-PSDrawIOPSClass` |
| `Get-PSDrawIOPSEnum` | ~18 | Enum AST extraction | `Find-PSDrawIOPSEnum` |
| `Get-PSDrawIOPSDependency` | ~39 | Call-site classification | `Find-PSDrawIOPSDependency` |
| `Build-PSDrawIOPSGraph` | ~40 | Graph assembly (no Language.* but extraction-half) | `Build-PSDrawIOPSModuleGraph` |

**Naming:** Analysis functions cannot share Public names (dot-source redefine). Distinct verbs: `Initialize-` / `Find-` / `Build-…ModuleGraph`.

---

## 2. `src/Analysis/` created (6 files, not exported)

```
src/Analysis/Initialize-PSDrawIOPSAnalysis.ps1
src/Analysis/Find-PSDrawIOPSFunction.ps1
src/Analysis/Find-PSDrawIOPSClass.ps1
src/Analysis/Find-PSDrawIOPSEnum.ps1
src/Analysis/Find-PSDrawIOPSDependency.ps1
src/Analysis/Build-PSDrawIOPSModuleGraph.ps1
```

- `Export-ModuleMember` still lists only the original six Public names.
- Smoke: all six Analysis names `exported=False`.
- `System.Management.Automation.Language` hits: Public=0, Analysis=11.

---

## 3. Public wrappers (thin)

Each Public file keeps comment-based help + `[CmdletBinding()]` (+ `SupportsShouldProcess` on New) and delegates in one line:

| Public | Body |
|---|---|
| `New-PSDrawIOPSAnalysis` | `Initialize-PSDrawIOPSAnalysis -Path $Path` (after ShouldProcess) |
| `Get-PSDrawIOPSFunction` | `Find-PSDrawIOPSFunction -Session $Session` |
| `Get-PSDrawIOPSClass` | `Find-PSDrawIOPSClass -Session $Session` |
| `Get-PSDrawIOPSEnum` | `Find-PSDrawIOPSEnum -Session $Session` |
| `Get-PSDrawIOPSDependency` | `Find-PSDrawIOPSDependency -Session $Session` |
| `Build-PSDrawIOPSGraph` | `Build-PSDrawIOPSModuleGraph -Session $Session` |

Public line counts: 13–14 each (help + param + one call).

---

## 4. Loader order (`src/PS.DrawIO.Provider.PowerShell.psm1`)

```
Classes → Declarations → Private → Analysis → Public
Export-ModuleMember: same six Public only
```

**Why this order**
- **Classes first** — types available to everything.
- **Declarations before Analysis/Public** — pure data; wall requires Declarations not to call Analysis; data may be read later without circular load.
- **Private before Analysis** — Analysis uses `Get-PSDrawIOPSAstExtent` / `Get-PSDrawIOPSSourceFile`.
- **Analysis before Public** — wrappers call Analysis functions.
- AGENTS.md lists `Classes → Private → Analysis → Public`; Declarations retained and placed before Analysis (data + wall).

---

## 5. Private helpers — KEEP in `src/Private/`

| Helper | Decision | Reason |
|---|---|---|
| `Get-PSDrawIOPSAstExtent` | **Stay Private** | Shared extent shaping utility, not an extraction pipeline |
| `Get-PSDrawIOPSSourceFile` | **Stay Private** | Shared file discovery utility |

Unit tests pin Private BaseNames under `src/Private/`. Moving them would break that pin without improving the wall (wall is Declarations ↛ Analysis).

---

## 6. Visibility: Analysis path → `Internal`

```powershell
$visibility = if ($entry.Key -match '[\\/]Private[\\/]') { 'Private' }
elseif ($entry.Key -match '[\\/]Analysis[\\/]') { 'Internal' }
else { 'Public' }
```

Self-analysis of `./src`: **Public=6, Private=2, Internal=6**.  
Unit pin Public=6 / Private=2 preserved. Internal is neither export variant.

---

## 7. Wall test (AST-based)

**Label unchanged** (Get-Label key): `Nothing in src/Declarations/` → full expanded name still  
`Nothing in src/Declarations/ calls anything in src/Analysis/ — enforced by a test`

**New assertion design**
1. Fail if `src/Analysis/` missing or empty (no vacuous empty∩empty).
2. Parse every Analysis `*.ps1` → `FunctionDefinitionAst` names → HashSet.
3. Parse every Declarations `*.ps1` → `CommandAst` command names.
4. Assert intersection empty.

Replaces vacuous: `(Get-Content …Declarations…) | Should -Not -Match 'Get-PSDrawIOPS'`.

---

## 8. Breach proof (verbatim)

Temporary Declarations body (non-executing function so module still loads):

```powershell
function Invoke-PSDrawIOWallBreach {
    Find-PSDrawIOPSFunction -Session $null
}
```

Pester wall It output:

```
[-] Nothing in `src/Declarations/` calls anything in `src/Analysis/` — enforced by a test 68ms
 at $declarationCalls | Should -BeNullOrEmpty -Because 'no file in src/Declarations/ may call a function defined in src/Analysis/', ...Provider.Acceptance.Tests.ps1:104
 Expected $null or empty, because no file in src/Declarations/ may call a function defined in src/Analysis/, but got 'PSDrawIO.Declarations.ps1:Find-PSDrawIOPSFunction'.
```

Revert: `git checkout -- src/Declarations/PSDrawIO.Declarations.ps1`  
`git diff -- src/Declarations/` → **empty** (clean).

Note: top-level call (not in function) also fails earlier at module import (`CommandNotFoundException`) because Declarations load before Analysis — that is load-order defense; the AST wall catches deferred/body calls.

---

## 9. Verification

### `./build/build.ps1 -Task Test`
- Discovery: **62**
- Passed: **58**
- Failed: **4**
- Skipped: **0**

### Same four FAIL labels only
1. Node types and edge types are declared separately, not merged into one collection  
2. Analyzes **itself** end to end, and the result is correct on inspection (SIGNOFF Commit empty)  
3. `README.md` — install → analyze → inspect graph in under 20 lines (SIGNOFF)  
4. `docs/PATTERNS.md` — **maintained during development**… (SIGNOFF)

No fifth failure after BOM fix (see below).

### Coverage (Unit + CodeCoverage)
| Scope | Coverage | Gate |
|---|---|---|
| `src/Public` | **100%** (7/7 commands, 6 files) | ≥90 ✓ |
| `src` overall | **94.84%** (426 commands, 18 files) | ≥80 ✓ |

(Build’s second overall pass reported 94.47% / 398 cmds depending on path set; both above gate.)

### PSScriptAnalyzer
Clean at Error/Warning after replacing Unicode arrows with ASCII in `Find-PSDrawIOPSFunction.ps1` comments (`PSUseBOMForUnicodeEncodedFile`).

### Smoke
- Import-Module force: 6 exports only  
- Self-analysis: Public=6 Private=2 Internal=6; Nodes=30 Edges=36  
- Sample.psm1: Nodes=7 Edges=3 Confidence=True  
- Pathological / Malicious fixtures: analyze without crash  
- Public: zero `Language` namespace references  

---

## 10. Deliberately NOT done

- No commit / push / PR  
- No SIGNOFF.json edits  
- No PROVIDER.md / AGENTS.md checkbox edits  
- No Registry or Terraform changes  
- No DoNotModify touches  
- No `.drawio` XML  
- No ModuleVersion / CHANGELOG history rewrite  
- Layout-hints acceptance Select-String left as-is (still passes)  

---

## 11. Uncommitted file set

```
 M src/PS.DrawIO.Provider.PowerShell.psm1
 M src/Public/*.ps1 (6)
 M tests/Acceptance/Provider.Acceptance.Tests.ps1
?? src/Analysis/ (6 files)
?? _AgentRequests.md
```

Declarations clean (no diff).
