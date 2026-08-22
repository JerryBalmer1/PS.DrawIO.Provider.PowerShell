# ADR 0004: Deliberate Test Failure Blocks the Packaging Step

## Status
Accepted

## Context
`build/build.ps1` runs tasks in fixed order when `$Task` defaults to `All`: Clean, then Analyze, then Test, then Package. The Test block fails the process on any Pester failure:

```powershell
# build/build.ps1 lines 18–24
if ($Task -in 'All', 'Test') {
        $isCI = [bool]$env:CI -or [bool]$env:TF_BUILD -or [bool]$env:GITHUB_ACTIONS
        $result = Invoke-Pester (Join-Path $root 'tests') -PassThru
        if ($result.FailedCount -gt 0) {
            if ($isCI) { exit 1 }
            throw "Pester: $($result.FailedCount) test(s) failed."
        }
```

The Package block is later and only runs if control reaches it:

```powershell
# build/build.ps1 lines 31–36
if ($Task -in 'All', 'Package') {
    Test-ModuleManifest $manifestPath | Out-Null
    New-Item -ItemType Directory -Path $packagePath -Force | Out-Null
    Copy-Item (Join-Path $root 'src/*') $packagePath -Recurse -Force
    Write-Output "Packaged module at $packagePath"
}
```

Provider v1 retains one deliberate failing acceptance test — "Node types and edge types are declared separately, not merged into one collection" — as contract evidence under ADR 0003 and Registry ADR 0002. That failure is required; the build's throw on `FailedCount -gt 0` is also required. Together they make the default path unreachable.

Measured on a clean tree with `./build/build.ps1` (no `-Task`):

- Outer summary: `Tests Passed: 61, Failed: 1`
- Host throw: `Pester: 1 test(s) failed.` at `build.ps1:23`
- `FULL_EXIT=1`
- `PACKAGED_LINE_COUNT=0` — `Write-Output "Packaged module at ..."` never appears

The same script with `./build/build.ps1 -Task Package` does package: it writes `Packaged module at ...\dist\PS.DrawIO.Provider.PowerShell`, and that folder contains `PS.DrawIO.Provider.PowerShell.psd1` / `.psm1` plus `Analysis`, `Classes`, `Declarations`, `Private`, and `Public`. `Test-ModuleManifest` on the packaged manifest reports Version `1.0.0`. Packaging is not broken; only the default `All` path is.

`PS.DrawIO.Registry/build/build.ps1` uses the same structure: Test throws (or `exit 1` in CI) on `FailedCount -gt 0` before a later Package block that emits `Packaged module at $packagePath`. Registry has no deliberate failing test today, so it has not hit this wall. The first time it ships a known-failing test under the same ordering, default `All` will stop before Package for the same reason.

Both behaviours are individually correct. The collision is the problem.

## Options considered

1. Accept the limitation. Keep the throw and the deliberate failure. Produce artifacts with `./build/build.ps1 -Task Package` when needed.
2. Add an expected-failure allowlist to `build.ps1` so default `All` can continue past named tests.
3. Weaken the Test throw, or `-Skip` / delete the node/edge acceptance test, so default `All` goes green and packages.

## Decision
Choose option 1.

- Do **not** add an expected-failure allowlist to `build.ps1`.
- Do **not** weaken the throw on `FailedCount -gt 0`.
- Do **not** `-Skip` or remove the failing node/edge acceptance test (ADR 0003).
- When a package artifact is needed, run `./build/build.ps1 -Task Package` explicitly.
- Do not build a bypass for a blockage that blocks nothing operational today: no PSGallery publication, no Core consumer, no downstream that requires `dist/`. That stays out of scope under AGENTS.md scope discipline.
- Revisit when something actually needs the default end-to-end artifact path, or when contract v2 resolves the failing test — whichever comes first.

## Consequences
The documented release path (`./build/build.ps1` with no arguments) does not complete end to end while the deliberate failure remains. The working packaging command is not written down in README or PROVIDER.md today; it should be recorded there (and kept next to the known-failure note) so operators are not left to rediscover `-Task Package` from this ADR alone.

CI is red on every run for the same single label. Exit code alone cannot distinguish a new regression from the known state. A human must read the failing test name. That is the real ongoing cost of keeping the evidence test live.

If an allowlist is ever added despite this decision, it must name specific tests with ADR citations and fail closed on anything else. That is a hard condition on any future change, not a plan to implement one now.
