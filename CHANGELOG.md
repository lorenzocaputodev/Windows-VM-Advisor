# Changelog

## 1.1.0

### Fixed
- Host RAM thresholds now use the nominal installed size. An 8 GB host reporting 7.6 GB is no longer treated as smaller than 8 GB, which wrongly blocked Windows 10 and Windows 11 and marked the host as RAM limited. Same for 16 GB hosts and the "strong host" tier.
- Windows 11 no longer depends on the host TPM, Secure Boot, or UEFI. The hypervisor provides them to the guest, so the recommendation now depends on RAM, storage, and SLAT. A note reminds the user to enable the virtual TPM and Secure Boot in the VM settings.
- Blocked hypervisors (virtualization disabled) are no longer downgraded to `limited` when Hyper-V or Memory Integrity is also enabled.
- VirtualBox is now `limited` instead of `blocked` when Hyper-V and Memory Integrity are both enabled. An explicit hypervisor preference falls back to the other option only when it is blocked or scores at least 20 points lower.
- Secure Boot is read from the registry when `Confirm-SecureBootUEFI` cannot run without elevation.
- Generic `SATA` or `Fixed hard disk media` labels no longer classify a drive as HDD. `Get-PhysicalDisk` media type is used when available.
- Rankings, labels, profile sizes, and readiness messaging no longer change with the RAM that happens to be free at run time. Low free RAM now only adds an advisory note and a readiness limitation. A guest whose target RAM had to be reduced for the host ranks slightly lower, so lighter guests still climb on small hosts.
- Multi-socket hosts report the cores and threads of every processor instead of only the first one.
- VMware and VirtualBox are also found under a relocated `Program Files` folder.
- `latest` is published through a staging folder, so a failed copy no longer leaves it empty. If the project folder is read-only, results go to `%LOCALAPPDATA%\Windows-VM-Advisor\Results`.

### Added
- `-Hypervisor auto|vmware|virtualbox` public option.
- A report note when the Hyper-V state cannot be verified.
- ARM and 32-bit hosts are reported as not ready, because the catalog only contains x64 guests.
- Windows 10 is flagged as end of support (14 October 2025): capped at `possible` with a security note.
- openSUSE Leap joins the catalog (13 guests).
- `scripts/update-examples.ps1` regenerates the sample outputs in `examples/` from the recorded host data; the samples were refreshed to match the current rules.
- Catalog entries can carry a `vm_note` (Rocky Linux 10 needs an x86-64-v3 CPU; Kali offers ready-made VMware and VirtualBox images) and a `strong_host_for_recommended` flag that replaces the hard-coded Fedora check.
- Debian's description now mentions choosing Xfce or LXQt for the lightest setup.
- A note when a Windows guest would leave the host less than the reserved memory.
- `scripts/check-catalog-links.ps1` for manual verification of the catalog links, and a catalog integrity test.
- PSScriptAnalyzer lint script and CI step, `.gitattributes`, and new unit tests for the changes above.

### Changed
- Recommendation score thresholds for Windows guests moved to `Get-AdvisorThresholds`.
- Core scripts are loaded automatically; the tool version has a single source (`Get-ToolVersion`).
- Renamed automatic-variable shadows (`$matches`, `$profile`) and removed unused variables.
