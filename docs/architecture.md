# Architecture

## High-level flow

1. Launch from `Windows-VM-Advisor.bat` or the internal PowerShell entrypoint under `src\entrypoints`
2. Collect host facts from Windows
3. Normalize those facts into a stable internal shape
4. Evaluate VM readiness
5. Rank the curated guest catalog
6. Format text outputs and `Details.json`
7. Publish results to `Results\latest` and `Results\archive\...`

## Layers

### 1. Launchers

- `Windows-VM-Advisor.bat` for normal users
- `src\entrypoints\Start-Windows-VM-Advisor.ps1` as the PowerShell entrypoint
- `src\cli\Invoke-VMAdvisor.ps1` as the internal orchestrator

### 2. Collectors

Small PowerShell functions that gather one domain of host information:

- Windows host details
- CPU and hardware virtualization state
- RAM
- storage
- firmware and Secure Boot
- TPM
- hypervisor presence and relevant Windows feature state

### 3. Catalog

A local JSON catalog under `src\core\catalog` stores the curated guest metadata used for ranking.

### 4. Rules

Deterministic logic that turns host facts into:

- VM readiness
- ranked guest recommendations
- per-guest VM profiles
- preferred hypervisor suggestions

### 5. Output formatting

Separate formatters produce:

- `System-Info.txt`
- `VM-Readiness.txt`
- `ISO-Recommendations.txt`
- `VM-Profiles.txt`
- `Details.json`
- the compact console summary

## Design principles

- Keep collectors separate from evaluation logic.
- Keep evaluation logic separate from formatting.
- Keep runtime fully local and deterministic.
- Prefer simple, documented thresholds over hidden heuristics.
- Fail softly when a Windows feature or cmdlet is unavailable.
- Keep the user-facing surface smaller than the internal implementation.
