# Deterministic rules

Windows-VM-Advisor uses local, deterministic rules and a curated guest catalog. It does not fetch live ranking data at runtime.

## Readiness rules

### NOT READY

Use `not_ready` when practical VM use is blocked, for example:

- hardware virtualization is not available
- hardware virtualization is disabled in firmware
- host RAM is below the practical desktop VM floor
- no local fixed drive with at least `40 GB` free remains suitable for VM storage
- no guest option remains practical after evaluating the host

### LIMITED

Use `limited` when the host can still run VMs, but lighter choices are safer, for example:

- host RAM is below `8 GB`
- the system drive is tight even though another fixed drive can hold VM files
- the preferred VM storage location is workable but still below `80 GB` free
- Hyper-V or Memory Integrity may interfere with some desktop hypervisors
- only conservative or downsized guest profiles make sense

### OK

Use `ok` when:

- no readiness blocker exists
- at least one guest reaches the `recommended` tier
- mainstream guest options fit without obvious host stress

## Guest ranking rules

- `Guest auto` stays neutral and lets the best practical entries rise naturally.
- `Guest windows` and `Guest linux` bias that family, but do not hard-filter the full ranked list.
- Lighter Linux options climb on constrained hosts.
- Linux Mint and Ubuntu LTS remain the strongest mainstream Linux desktop choices.
- Debian Stable and Lubuntu remain the clearest lightweight Linux options on tighter hosts.
- Fedora Workstation, Arch Linux, and NixOS stay available for stronger or more technical hosts.
- Rocky Linux and FreeBSD remain valid specialist guests, but they usually fit lab-oriented or server-like use better than a default desktop VM.
- Fit reasons should explain the guest’s practical role on the host, not just a resource cap.
- Concrete host blockers should outrank role-oriented scope wording when a guest is clearly blocked by storage, RAM, firmware, or another practical host constraint.
- Windows 10 remains the more forgiving Windows fallback.
- Windows 11 ranks high only when UEFI, Secure Boot, TPM 2.0, RAM, and storage are favorable.
- LTSC and IoT Windows variants are intentionally excluded from the main catalog to keep the product simpler and easier to understand.
- Kali Linux stays specialist by metadata and usually remains below default desktop choices unless the surrounding host context makes it a sensible lab guest.
- Recommended, Possible, and Not recommended should separate genuinely practical fits from second-tier or specialist options.

## Hypervisor rules

- Respect the explicit hypervisor preference when it is still practical.
- Prefer an already installed suitable hypervisor in `auto` mode.
- Fall back to the safer supported option when the preferred one is blocked.
- Treat Hyper-V and Memory Integrity as a heavier penalty for VirtualBox than for VMware Workstation.

## VM profile rules

- Start from family defaults and the selected `Mode`.
- Shift the profile using the catalog entry’s typical fit:
  - `light` guests lean one step lighter
  - `balanced` guests keep the requested mode
  - `performance` guests lean one step heavier
- Cap vCPU to half of the host’s logical threads.
- Cap memory against host-safe headroom while preserving a practical guest minimum.
- Distinguish structural profile reductions from temporary operating pressure caused by currently low free RAM.
- Cap disk to preserve host free space.
- Choose the best VM storage location per guest from the available local fixed drives.
- Record profile reduction notes when the host forces a smaller starting profile.

## Safety principle

When uncertain, prefer the safer and lighter guest or VM profile instead of an aggressive one.
