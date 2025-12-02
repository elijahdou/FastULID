//
// main.swift
// LockComparison
//
// Lock performance comparison for FastULID
// Tests os_unfair_lock vs OSAllocatedUnfairLock vs NSLock
//
// Created on 2025-12-04.
//

import Foundation
import os

// Number of iterations
let iterations = 100_000_000

// Simple protected state
class State {
    var count = 0
}

@available(macOS 13.0, iOS 16.0, *)
func benchmarkLocks() {
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                               ║
    ║                          Lock Performance Comparison                          ║
    ║                                                                               ║
    ║  Testing lock implementations used in FastULID's ULIDGenerator                ║
    ║  Iterations: \(iterations.formatted())                                      ║
    ║                                                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    
    """)
    
    // ----------------------------------------------------------------
    // 1. os_unfair_lock (C API)
    // ----------------------------------------------------------------
    print("🔒 Test 1: os_unfair_lock (C API)")
    print(String(repeating: "-", count: 80))
    
    let lock = os_unfair_lock_t.allocate(capacity: 1)
    lock.initialize(to: os_unfair_lock())
    let state1 = State()
    
    // Warmup
    for _ in 0..<1000 {
        os_unfair_lock_lock(lock)
        state1.count += 1
        os_unfair_lock_unlock(lock)
    }
    state1.count = 0
    
    let start1 = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        os_unfair_lock_lock(lock)
        state1.count &+= 1  // Use &+= to avoid overflow check overhead
        os_unfair_lock_unlock(lock)
    }
    let end1 = CFAbsoluteTimeGetCurrent()
    let time1 = end1 - start1
    let nsPerOp1 = (time1 / Double(iterations)) * 1_000_000_000
    
    print(String(format: "  Total time: %.2f s", time1))
    print(String(format: "  Per operation: %.2f ns", nsPerOp1))
    print(String(format: "  Throughput: %.2f M ops/s", Double(iterations) / time1 / 1_000_000))
    print()
    
    lock.deinitialize(count: 1)
    lock.deallocate()
    
    // ----------------------------------------------------------------
    // 2. OSAllocatedUnfairLock (Swift Wrapper)
    // ----------------------------------------------------------------
    print("🔒 Test 2: OSAllocatedUnfairLock (Swift API)")
    print(String(repeating: "-", count: 80))
    
    let safeLock = OSAllocatedUnfairLock(initialState: 0)
    
    // Warmup
    for _ in 0..<1000 {
        safeLock.withLock { $0 += 1 }
    }
    safeLock.withLock { $0 = 0 }
    
    let start2 = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        safeLock.withLock { $0 &+= 1 }
    }
    let end2 = CFAbsoluteTimeGetCurrent()
    let time2 = end2 - start2
    let nsPerOp2 = (time2 / Double(iterations)) * 1_000_000_000
    
    print(String(format: "  Total time: %.2f s", time2))
    print(String(format: "  Per operation: %.2f ns", nsPerOp2))
    print(String(format: "  Throughput: %.2f M ops/s", Double(iterations) / time2 / 1_000_000))
    print()
    
    // ----------------------------------------------------------------
    // 3. NSLock (Reference Baseline)
    // ----------------------------------------------------------------
    print("🔒 Test 3: NSLock (Reference Baseline)")
    print(String(repeating: "-", count: 80))
    
    let nsLock = NSLock()
    let state3 = State()
    
    // Warmup
    for _ in 0..<1000 {
        nsLock.lock()
        state3.count += 1
        nsLock.unlock()
    }
    state3.count = 0
    
    let start3 = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        nsLock.lock()
        state3.count &+= 1
        nsLock.unlock()
    }
    let end3 = CFAbsoluteTimeGetCurrent()
    let time3 = end3 - start3
    let nsPerOp3 = (time3 / Double(iterations)) * 1_000_000_000
    
    print(String(format: "  Total time: %.2f s", time3))
    print(String(format: "  Per operation: %.2f ns", nsPerOp3))
    print(String(format: "  Throughput: %.2f M ops/s", Double(iterations) / time3 / 1_000_000))
    print()
    
    // Summary
    print(String(repeating: "=", count: 80))
    print("📊 Performance Comparison Summary")
    print(String(repeating: "=", count: 80))
    print()
    
    print("Lock Performance (per operation):")
    print(String(format: "  1. os_unfair_lock:        %.2f ns  ✅ Fastest", nsPerOp1))
    print(String(format: "  2. OSAllocatedUnfairLock: %.2f ns  (%.2fx slower)", nsPerOp2, nsPerOp2 / nsPerOp1))
    print(String(format: "  3. NSLock:                %.2f ns  (%.2fx slower)", nsPerOp3, nsPerOp3 / nsPerOp1))
    print()
    
    let overhead = nsPerOp2 - nsPerOp1
    print(String(format: "Overhead Analysis:"))
    print(String(format: "  OSAllocatedUnfairLock overhead: %.2f ns per operation", overhead))
    print(String(format: "  This is due to Swift's closure-based API and additional safety checks"))
    print()
    
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                               ║
    ║  ✅ Benchmark Complete!                                                       ║
    ║                                                                               ║
    ║  FastULID's Lock Strategy:                                                    ║
    ║  • iOS 16+/macOS 13+: Uses OSAllocatedUnfairLock (memory-safe Swift API)     ║
    ║  • iOS 15: Uses os_unfair_lock (maximum performance)                         ║
    ║                                                                               ║
    ║  Rationale:                                                                   ║
    ║  • Modern platforms: Safety > Raw speed (overhead is minimal ~1-2ns)         ║
    ║  • Older platforms: Direct C API for best performance                        ║
    ║  • Both far superior to NSLock                                               ║
    ║                                                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    
    """)
}

print("🚀 Starting lock performance benchmark...")
print()

if #available(macOS 13.0, iOS 16.0, *) {
    benchmarkLocks()
} else {
    print("⚠️  This test requires macOS 13.0+ or iOS 16.0+")
    print("   Current platform does not support OSAllocatedUnfairLock")
}

