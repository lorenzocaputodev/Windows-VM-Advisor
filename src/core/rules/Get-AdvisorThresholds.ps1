function Get-AdvisorThresholds {
    return [pscustomobject]@{
        readiness_blocked_storage_free_gb = 40
        readiness_limited_storage_free_gb = 80
        readiness_blocked_ram_gb          = 4
        readiness_limited_ram_gb          = 8
        host_reserved_memory_gb           = 4
        host_reserved_disk_gb             = 20
        host_strong_memory_gb             = 16
        host_strong_storage_free_gb       = 150
        host_strong_threads               = 8
        windows_guest_min_memory_mb       = 4096
        linux_guest_min_memory_mb         = 2048
        windows_guest_min_disk_gb         = 64
        linux_guest_min_disk_gb           = 32
        windows11_min_memory_gb           = 8
        windows11_good_memory_gb          = 16
        windows11_min_storage_gb          = 64
        windows11_good_storage_gb         = 100
        windows10_min_memory_gb           = 8
        linux_min_memory_gb               = 4
        profiles                          = [pscustomobject]@{
            windows = [pscustomobject]@{
                light       = [pscustomobject]@{
                    vcpu      = 2
                    memory_mb = 4096
                    disk_gb   = 64
                }
                balanced    = [pscustomobject]@{
                    vcpu      = 2
                    memory_mb = 6144
                    disk_gb   = 80
                }
                performance = [pscustomobject]@{
                    vcpu      = 4
                    memory_mb = 8192
                    disk_gb   = 100
                }
            }
            linux   = [pscustomobject]@{
                light       = [pscustomobject]@{
                    vcpu      = 2
                    memory_mb = 2048
                    disk_gb   = 40
                }
                balanced    = [pscustomobject]@{
                    vcpu      = 2
                    memory_mb = 4096
                    disk_gb   = 48
                }
                performance = [pscustomobject]@{
                    vcpu      = 4
                    memory_mb = 6144
                    disk_gb   = 64
                }
            }
        }
    }
}
