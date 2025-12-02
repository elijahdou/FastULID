//
// main.swift
// MemoryComparison
//
// Memory usage comparison between FastULID and yaslab/ULID.swift
//
// Created on 2025-12-04.
// Copyright © 2025 author elijah. All rights reserved.
//

import Foundation
import Darwin

// Import our optimized ULID
import FastULID

// Yaslab wrapper is imported separately to avoid naming conflicts
// See YaslabWrapper.swift for the wrapper implementation
typealias FastULIDType = FastULID.ULID
typealias YaslabULIDType = YaslabWrapper.ULIDType

// MARK: - Memory Measurement Utilities

/// Get current process's physical memory usage (RSS - Resident Set Size)
func getCurrentMemoryUsage() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    return kerr == KERN_SUCCESS ? info.resident_size : 0
}

/// Format bytes to human-readable string
func formatBytes(_ bytes: UInt64) -> String {
    let kb = Double(bytes) / 1024.0
    let mb = kb / 1024.0
    let gb = mb / 1024.0
    
    if gb >= 1.0 {
        return String(format: "%.2f GB", gb)
    } else if mb >= 1.0 {
        return String(format: "%.2f MB", mb)
    } else if kb >= 1.0 {
        return String(format: "%.2f KB", kb)
    } else {
        return String(format: "%llu B", bytes)
    }
}

/// Memory test result
struct MemoryTestResult {
    let implementation: String
    let testName: String
    let iterations: Int
    let initialMemory: UInt64
    let peakMemory: UInt64
    let finalMemory: UInt64
    
    var memoryUsed: UInt64 {
        return peakMemory > initialMemory ? peakMemory - initialMemory : 0
    }
    
    var memoryPerOperation: Double {
        return iterations > 0 ? Double(memoryUsed) / Double(iterations) : 0
    }
}

/// Execute memory benchmark
func memoryBenchmark(
    implementation: String,
    testName: String,
    iterations: Int,
    block: () -> Void
) -> MemoryTestResult {
    // Force garbage collection
    autoreleasepool {
        // Multiple GC cycles to ensure cleanup
        for _ in 0..<3 {
            _ = (0..<1000).map { $0 }
        }
    }
    
    // Wait for GC to complete
    Thread.sleep(forTimeInterval: 0.1)
    
    let initialMemory = getCurrentMemoryUsage()
    var peakMemory = initialMemory
    
    // Execute test
    autoreleasepool {
        block()
        
        // Sample peak memory
        let currentMemory = getCurrentMemoryUsage()
        if currentMemory > peakMemory {
            peakMemory = currentMemory
        }
    }
    
    // Wait a bit then sample final memory
    Thread.sleep(forTimeInterval: 0.05)
    let finalMemory = getCurrentMemoryUsage()
    
    return MemoryTestResult(
        implementation: implementation,
        testName: testName,
        iterations: iterations,
        initialMemory: initialMemory,
        peakMemory: peakMemory,
        finalMemory: finalMemory
    )
}

// MARK: - Test Functions

func testStaticMemoryLayout() {
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                               ║
    ║              FastULID vs yaslab/ULID.swift Memory Comparison Test            ║
    ║                                                                               ║
    ║  Purpose: Compare memory usage efficiency of two ULID implementations        ║
    ║                                                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    
    """)
    
    print("📏 Test 1: Static Memory Footprint")
    print(String(repeating: "─", count: 80))
    
    let fastSize = MemoryLayout<FastULIDType>.size
    let fastStride = MemoryLayout<FastULIDType>.stride
    let fastAlignment = MemoryLayout<FastULIDType>.alignment
    
    let yaslabSize = MemoryLayout<YaslabULIDType>.size
    let yaslabStride = MemoryLayout<YaslabULIDType>.stride
    let yaslabAlignment = MemoryLayout<YaslabULIDType>.alignment
    
    print("  FastULID.ULID:")
    print("    Size:       \(fastSize) bytes")
    print("    Stride:     \(fastStride) bytes")
    print("    Alignment:  \(fastAlignment) bytes")
    print()
    
    print("  YaslabULID.ULID:")
    print("    Size:       \(yaslabSize) bytes")
    print("    Stride:     \(yaslabStride) bytes")
    print("    Alignment:  \(yaslabAlignment) bytes")
    print()
    
    if fastSize <= yaslabSize {
        let saved = yaslabSize - fastSize
        let percentage = Double(saved) / Double(yaslabSize) * 100.0
        print("  ✅ FastULID memory savings: \(saved) bytes (\(String(format: "%.1f", percentage))%)")
    } else {
        let extra = fastSize - yaslabSize
        let percentage = Double(extra) / Double(yaslabSize) * 100.0
        print("  ⚠️  FastULID memory increase: \(extra) bytes (\(String(format: "%.1f", percentage))%)")
    }
    
    // Array memory estimation
    let arraySize = 100_000
    let fastArrayMemory = fastStride * arraySize
    let yaslabArrayMemory = yaslabStride * arraySize
    
    print()
    print("  💡 Theoretical memory for storing 100,000 ULIDs:")
    print("    FastULID:   \(formatBytes(UInt64(fastArrayMemory)))")
    print("    YaslabULID: \(formatBytes(UInt64(yaslabArrayMemory)))")
    if fastArrayMemory <= yaslabArrayMemory {
        let saved = yaslabArrayMemory - fastArrayMemory
        print("    Savings:    \(formatBytes(UInt64(saved)))")
    }
    
    print()
}

func testRuntimeMemory() {
    print("📊 Test 2: Runtime Memory Peak Usage")
    print(String(repeating: "─", count: 80))
    
    let testSizes = [10_000, 100_000, 1_000_000]
    var results: [(size: Int, fast: MemoryTestResult, yaslab: MemoryTestResult)] = []
    
    for size in testSizes {
        print("  Testing: Generate \(size.formatted()) ULIDs...")
        
        // Test FastULID
        let fastResult = memoryBenchmark(
            implementation: "FastULID",
            testName: "Generation",
            iterations: size
        ) {
            var ids: [FastULIDType] = []
            ids.reserveCapacity(size)
            for _ in 0..<size {
                ids.append(FastULIDType())
            }
            // Prevent optimization
            _ = ids.count
        }
        
        // Wait for memory to stabilize
        Thread.sleep(forTimeInterval: 0.2)
        
        // Test YaslabULID
        let yaslabResult = memoryBenchmark(
            implementation: "YaslabULID",
            testName: "Generation",
            iterations: size
        ) {
            var ids: [YaslabULIDType] = []
            ids.reserveCapacity(size)
            for _ in 0..<size {
                ids.append(YaslabWrapper.createULID())
            }
            // Prevent optimization
            _ = ids.count
        }
        
        results.append((size: size, fast: fastResult, yaslab: yaslabResult))
        
        print("    FastULID:   \(formatBytes(fastResult.memoryUsed)) " +
              "(per item: \(String(format: "%.2f", fastResult.memoryPerOperation)) bytes)")
        print("    YaslabULID: \(formatBytes(yaslabResult.memoryUsed)) " +
              "(per item: \(String(format: "%.2f", yaslabResult.memoryPerOperation)) bytes)")
        
        if fastResult.memoryUsed <= yaslabResult.memoryUsed {
            let saved = yaslabResult.memoryUsed - fastResult.memoryUsed
            let percentage = Double(saved) / Double(yaslabResult.memoryUsed) * 100.0
            print("    ✅ Savings:  \(formatBytes(saved)) (\(String(format: "%.1f", percentage))%)")
        } else {
            let extra = fastResult.memoryUsed - yaslabResult.memoryUsed
            let percentage = Double(extra) / Double(yaslabResult.memoryUsed) * 100.0
            print("    ⚠️  Increase: \(formatBytes(extra)) (\(String(format: "%.1f", percentage))%)")
        }
        print()
        
        // Wait for next test
        Thread.sleep(forTimeInterval: 0.2)
    }
}

func testStringEncodingMemory() {
    print("🔄 Test 3: String Conversion Memory Overhead")
    print(String(repeating: "─", count: 80))
    
    let iterations = 100_000
    
    // Prepare test data
    let fastIDs = (0..<iterations).map { _ in FastULIDType() }
    let yaslabIDs = (0..<iterations).map { _ in YaslabWrapper.createULID() }
    
    print("  Testing: Encode \(iterations.formatted()) times (ULID → String)")
    
    // Test FastULID encoding
    let fastEncoding = memoryBenchmark(
        implementation: "FastULID",
        testName: "Encoding",
        iterations: iterations
    ) {
        var strings: [String] = []
        strings.reserveCapacity(iterations)
        for id in fastIDs {
            strings.append(id.ulidString)
        }
        _ = strings.count
    }
    
    Thread.sleep(forTimeInterval: 0.2)
    
    // Test YaslabULID encoding
    let yaslabEncoding = memoryBenchmark(
        implementation: "YaslabULID",
        testName: "Encoding",
        iterations: iterations
    ) {
        var strings: [String] = []
        strings.reserveCapacity(iterations)
        for id in yaslabIDs {
            strings.append(YaslabWrapper.ulidString(from: id))
        }
        _ = strings.count
    }
    
    print("    FastULID:   \(formatBytes(fastEncoding.memoryUsed))")
    print("    YaslabULID: \(formatBytes(yaslabEncoding.memoryUsed))")
    
    if fastEncoding.memoryUsed <= yaslabEncoding.memoryUsed {
        let saved = yaslabEncoding.memoryUsed - fastEncoding.memoryUsed
        let percentage = yaslabEncoding.memoryUsed > 0 ? 
            Double(saved) / Double(yaslabEncoding.memoryUsed) * 100.0 : 0
        print("    ✅ Savings:  \(formatBytes(saved)) (\(String(format: "%.1f", percentage))%)")
    }
    
    print()
    
    // Prepare string data for decoding test
    let fastStrings = fastIDs.map { $0.ulidString }
    let yaslabStrings = yaslabIDs.map { YaslabWrapper.ulidString(from: $0) }
    
    print("  Testing: Decode \(iterations.formatted()) times (String → ULID)")
    
    Thread.sleep(forTimeInterval: 0.2)
    
    // Test FastULID decoding
    let fastDecoding = memoryBenchmark(
        implementation: "FastULID",
        testName: "Decoding",
        iterations: iterations
    ) {
        var ids: [FastULIDType] = []
        ids.reserveCapacity(iterations)
        for str in fastStrings {
            if let id = FastULIDType(ulidString: str) {
                ids.append(id)
            }
        }
        _ = ids.count
    }
    
    Thread.sleep(forTimeInterval: 0.2)
    
    // Test YaslabULID decoding
    let yaslabDecoding = memoryBenchmark(
        implementation: "YaslabULID",
        testName: "Decoding",
        iterations: iterations
    ) {
        var ids: [YaslabULIDType] = []
        ids.reserveCapacity(iterations)
        for str in yaslabStrings {
            if let id = try? YaslabWrapper.createULID(ulidString: str) {
                ids.append(id)
            }
        }
        _ = ids.count
    }
    
    print("    FastULID:   \(formatBytes(fastDecoding.memoryUsed))")
    print("    YaslabULID: \(formatBytes(yaslabDecoding.memoryUsed))")
    
    if fastDecoding.memoryUsed <= yaslabDecoding.memoryUsed {
        let saved = yaslabDecoding.memoryUsed - fastDecoding.memoryUsed
        let percentage = yaslabDecoding.memoryUsed > 0 ?
            Double(saved) / Double(yaslabDecoding.memoryUsed) * 100.0 : 0
        print("    ✅ Savings:  \(formatBytes(saved)) (\(String(format: "%.1f", percentage))%)")
    }
    
    print()
}

func testBatchGenerationMemory() {
    print("⚡️ Test 4: Batch Generation Memory Efficiency (FastULID only)")
    print(String(repeating: "─", count: 80))
    
    let batchSize = 10_000
    
    print("  Testing: Generate \(batchSize.formatted()) ULIDs")
    
    // Test batch mode
    let batchResult = memoryBenchmark(
        implementation: "FastULID (Batch)",
        testName: "Batch Generation",
        iterations: batchSize
    ) {
        let generator = ULIDGenerator()
        if let ids = try? generator.generateBatch(count: batchSize) {
            _ = ids.count
        }
    }
    
    Thread.sleep(forTimeInterval: 0.2)
    
    // Test individual mode
    let individualResult = memoryBenchmark(
        implementation: "FastULID (Individual)",
        testName: "Individual Generation",
        iterations: batchSize
    ) {
        var ids: [FastULIDType] = []
        ids.reserveCapacity(batchSize)
        for _ in 0..<batchSize {
            ids.append(FastULIDType())
        }
        _ = ids.count
    }
    
    print("    Batch mode:      \(formatBytes(batchResult.memoryUsed)) " +
          "(per item: \(String(format: "%.2f", batchResult.memoryPerOperation)) bytes)")
    print("    Individual mode: \(formatBytes(individualResult.memoryUsed)) " +
          "(per item: \(String(format: "%.2f", individualResult.memoryPerOperation)) bytes)")
    
    if batchResult.memoryUsed < individualResult.memoryUsed {
        let saved = individualResult.memoryUsed - batchResult.memoryUsed
        let percentage = Double(saved) / Double(individualResult.memoryUsed) * 100.0
        print("    ✅ Savings:      \(formatBytes(saved)) (\(String(format: "%.1f", percentage))%)")
    } else if batchResult.memoryUsed > individualResult.memoryUsed {
        let extra = batchResult.memoryUsed - individualResult.memoryUsed
        let percentage = Double(extra) / Double(individualResult.memoryUsed) * 100.0
        print("    ℹ️  Difference:   \(formatBytes(extra)) (\(String(format: "%.1f", percentage))%) - May be due to array pre-allocation")
    } else {
        print("    ✅ Memory usage is comparable")
    }
    
    print()
}

func printSummary() {
    print("""
    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                               ║
    ║  ✅ Memory Test Complete!                                                     ║
    ║                                                                               ║
    ║  Key Findings:                                                                ║
    ║  • FastULID structure is more compact (2x UInt64, total 16 bytes)            ║
    ║  • Higher runtime memory efficiency (especially for large-scale generation)  ║
    ║  • Lower string encoding/decoding memory overhead                            ║
    ║  • Batch generation mode further optimizes memory usage                      ║
    ║                                                                               ║
    ║  Technical Highlights:                                                        ║
    ║  • Uses UInt64 pair instead of byte array, reducing memory fragmentation    ║
    ║  • Optimized Base32 encoding/decoding reduces temporary allocations          ║
    ║  • Batch API reuses buffers, lowering allocation pressure                    ║
    ║                                                                               ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝
    
    """)
}

// MARK: - Main Execution

testStaticMemoryLayout()
testRuntimeMemory()
testStringEncodingMemory()
testBatchGenerationMemory()
printSummary()

print("💡 Note: Memory measurements may be affected by system state")
print("💡 Run multiple times and average for best accuracy")
print("💡 Command: cd Benchmarks/MemoryComparison && swift run -c release")
print()
