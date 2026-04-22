# Data model

The stable machine-readable output is `Details.json`.

## Top-level shape

- `tool_version`
- `generated_at`
- `inputs`
- `system_information`
- `vm_readiness`
- `recommendations`

## inputs

- `guest_preference`
  Expected values:
  - `auto`
  - `windows`
  - `linux`
- `mode`
  Expected values:
  - `light`
  - `balanced`
  - `performance`
- `usage`
  Current fixed value:
  - `general_testing`
- `hypervisor_preference`

## system_information

### system_information.os

- `name`
- `version`
- `build`
- `architecture`

### system_information.cpu

- `model`
- `manufacturer`
- `cores`
- `threads`
- `max_clock_mhz`
- `virtualization_supported`
- `virtualization_enabled_in_firmware`
- `slat_supported`

### system_information.memory

- `total_gb`
- `free_gb`
- `module_count`

### system_information.storage

- `system_drive`
- `system_drive_fs`
- `system_drive_total_gb`
- `system_drive_free_gb`
- `physical_media_hint`
- `drives`
- `preferred_vm_storage`

### system_information.storage.drives[]

- `drive_letter`
- `is_system_drive`
- `filesystem`
- `total_gb`
- `free_gb`
- `storage_type_hint`
- `vm_storage_suitable`

### system_information.storage.preferred_vm_storage

This is either:

- an object describing the best current local fixed drive for VM storage, or
- `null` when no practical local VM storage location is available

When present it contains the same fields as `system_information.storage.drives[]`.

### system_information.firmware

- `boot_mode`
- `secure_boot`

### system_information.tpm

- `present`
- `ready`
- `version`

### system_information.hypervisors

- `vmware_workstation_installed`
- `virtualbox_installed`

### system_information.windows_features

- `hyperv_enabled`
- `memory_integrity_enabled`
- `device_guard_available`

### system_information.notes

Array of informational notes about detection fidelity. Always present.

## vm_readiness

- `state`
  Expected values:
  - `ok`
  - `limited`
  - `not_ready`
- `takeaway`
- `headline`
- `primary_reason`
- `blockers`
- `limitations`
- `checks`

### vm_readiness.checks[]

- `id`
- `label`
- `status`
  Expected values:
  - `ok`
  - `warning`
  - `blocked`
  - `info`
- `details`

## recommendations

Array of ranked recommendation entries, ordered from best practical fit to worst fit.

Each entry contains:

- `id`
- `display_name`
- `family`
- `flavor`
- `category`
- `architecture`
- `official_download_page`
- `official_release_page`
- `compatibility_label`
  Expected values:
  - `recommended`
  - `possible`
  - `not_recommended`
- `fit_reason`
- `preferred_hypervisor`
- `vm_profile`
- `notes`

### recommendations[].vm_profile

This is either:

- an object for `recommended` and `possible` entries, or
- `null` for `not_recommended` entries

When present it contains:

- `vcpu`
- `memory_mb`
- `disk_gb`
- `firmware`
- `secure_boot`
- `tpm`
- `network`
- `storage_location`

## Public contract rule

Raw internal scores are not exposed in `Details.json`.
