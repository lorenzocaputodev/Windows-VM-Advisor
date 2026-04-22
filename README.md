<p align="center">
  <img src="assets/Banner-VM-Advisor.png" alt="Windows-VM-Advisor banner" />
</p>

# Windows-VM-Advisor

A lightweight Windows tool that inspects the current PC, evaluates virtualization readiness, ranks practical guest OS options, and generates clear result files for manual VM setup in **VMware Workstation** or **Oracle VirtualBox**.

## ✨ Overview

Windows-VM-Advisor is built for one clear job and it stays local, deterministic, and focused.

---

## ✅ What it does

- Inspects the current Windows host for VM-relevant hardware and system details
- Evaluates practical VM readiness with clear blockers, limitations, and takeaways
- Ranks sensible guest OS options using a simple local ruleset
- Suggests practical starting VM profiles for usable guests
- Identifies the best storage location for VM files when multiple drives are available
- Writes clean user-facing output files plus a stable `Details.json`

---

## 🚀 Quick start

For best results, run as administrator:

```text
Windows-VM-Advisor.bat
```

You can also launch it from PowerShell:

```powershell
.\Windows-VM-Advisor.bat
```

### Public options

- `-Guest auto|windows|linux`
- `-Mode light|balanced|performance`

### Examples

```powershell
.\Windows-VM-Advisor.bat -Guest auto -Mode balanced
.\Windows-VM-Advisor.bat -Guest linux -Mode performance
.\Windows-VM-Advisor.bat -Guest windows -Mode light
```

### Advanced usage

Advanced PowerShell usage is available through the internal entrypoint:

```powershell
powershell -ExecutionPolicy Bypass -File .\src\entrypoints\Start-Windows-VM-Advisor.ps1
```

---

## 🧭 How it works

Windows-VM-Advisor follows a simple flow:

**host analysis → readiness evaluation → guest ranking → VM profile suggestions**

A successful run writes results to:

- `Results\latest\`
- `Results\archive\YYYYMMDD-HHMMSS\`

---

## 📄 Output files

Each run generates:

- `System-Info.txt` — hardware, firmware, storage, hypervisor, and Windows feature summary
- `VM-Readiness.txt` — readiness state, blockers, limitations, checks, and takeaway
- `ISO-Recommendations.txt` — ranked guest list with best-fit guidance
- `VM-Profiles.txt` — suggested starting VM settings for usable guests
- `Details.json` — stable machine-readable output

---

## 🖥️ Supported hypervisors

- VMware Workstation
- Oracle VirtualBox

---

## 💿 Supported guest catalog

### Windows
- Windows 10
- Windows 11

### Linux
- Linux Mint
- Ubuntu LTS
- Debian Stable
- Fedora Workstation
- Lubuntu
- Kali Linux
- Arch Linux
- Rocky Linux
- NixOS

### Unix-like / BSD
- FreeBSD

**Note:** leaner or specialized Windows variants such as LTSC or IoT can still make sense in specific scenarios, but they are intentionally kept out of the main catalog to keep the tool simple and focused.

---

## ⚠️ Limitations

- It does not download ISOs
- It does not create or modify VMs
- It targets **Windows hosts only**
- Rankings are local and deterministic, not based on live popularity or download data
- Detection quality may be reduced on restricted systems or when some Windows commands are unavailable

---

## 🛠️ Development

Bootstrap the development environment:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap-dev.ps1
```

Run the test suite:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-tests.ps1
```

Validate the sample output contract:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-sample-report.ps1
```

Further technical documentation:

- `docs/architecture.md` — runtime structure and layering
- `docs/data-model.md` — `Details.json` contract and field layout
- `docs/rules.md` — readiness, ranking, and VM profile rules

---

## 📁 Repository structure

- `Windows-VM-Advisor.bat` — main launcher for Windows users
- `src/entrypoints/Start-Windows-VM-Advisor.ps1` — internal PowerShell entrypoint
- `src/` — collectors, rules, catalog, output formatters, utilities, and internal CLI
- `scripts/` — bootstrap, test, and validation helpers
- `tests/` — unit and integration tests
- `schemas/` — JSON schema for `Details.json`
- `examples/` — sample output files
- `docs/` — technical documentation
- `.github/workflows/` — CI workflow

---

## 🎯 Scope

Windows-VM-Advisor is not a VM manager.

It is a focused assessment tool for answering three practical questions:

1. **Is this Windows host in a good state for VM use?**
2. **Which guest types make the most sense here?**
3. **What is a safe and sensible starting profile for each one?**

---

## 🤖 **Notes**

This project was designed and refined by me, with targeted AI support in selected phases such as code review, refactoring, copy polishing, and visual or technical refinement.

AI was used as a support tool, not as a substitute for my work. Direction, final decisions, validation, and overall quality were handled by me.