# Changelog

## 1.1.0

### Fixed
- 8 GB and 16 GB hosts are no longer treated as smaller because Windows reports slightly less RAM.
- Windows 11 no longer depends on the host TPM, Secure Boot, or UEFI.
- Rankings no longer change with the RAM free at run time.
- VirtualBox is `limited`, not `blocked`, with Hyper-V and Memory Integrity; blocked hypervisors stay blocked.
- Secure Boot is read without elevation; unverifiable Hyper-V state is reported.
- Better storage type, multi-socket CPU, and install path detection.
- `latest` results are published safely, with a fallback folder if the project is read-only.

### Added
- openSUSE Leap (13 guests) and per-guest notes (Rocky Linux CPU requirement, Kali ready-made VMs).
- `-Hypervisor auto|vmware|virtualbox` option.
- ARM and 32-bit hosts reported as not ready; Windows 10 flagged as end of support.
- Lint, catalog link check, and example regeneration scripts.
