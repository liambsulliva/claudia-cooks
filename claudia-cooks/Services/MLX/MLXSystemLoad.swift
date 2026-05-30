//
//  MLXSystemLoad.swift
//  claudia-cooks
//

import Darwin
import Foundation

struct MLXSystemLoad: Sendable {
    let physicalMemoryBytes: UInt64
    let availableMemoryBytes: UInt64?

    var shouldUseLowMemoryMode: Bool {
        if physicalMemoryBytes <= MLXConfiguration.shared.lowMemoryPhysicalThresholdBytes {
            return true
        }

        guard let availableMemoryBytes else {
            return false
        }

        return availableMemoryBytes < MLXConfiguration.shared.lowMemoryAvailableThresholdBytes
    }

    static func current() -> MLXSystemLoad {
        MLXSystemLoad(
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            availableMemoryBytes: Self.readAvailableMemoryBytes()
        )
    }

    private static func readAvailableMemoryBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let reclaimable = UInt64(stats.free_count + stats.inactive_count) * pageSize
        return reclaimable
    }
}
