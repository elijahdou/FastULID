//
// main.swift
// ULIDBenchmark
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// 2. Swift vs C implementation (via bridging)
// 3. Performance metrics for different operations
//

import Foundation
import FastULID

// MARK: - Local Test Helpers

/// Fixed time provider (for testing)
public struct FixedTimeProvider: TimeProvider {
    
    /// Fixed timestamp (milliseconds)
    private let fixedTimestamp: UInt64
    
    /// Initialize fixed time provider
    ///
    /// - Parameter timestamp: Fixed timestamp (milliseconds)
    public init(timestamp: UInt64) {
        self.fixedTimestamp = timestamp
    }
    
    /// Initialize fixed time provider
    ///
    /// - Parameter date: Fixed date
    public init(date: Date) {
        self.fixedTimestamp = UInt64(date.timeIntervalSince1970 * 1000.0)
    }
    
    /// Get fixed timestamp
    @inline(__always)
    public func currentMilliseconds() -> UInt64 {
        return fixedTimestamp
    }
}

// MARK: - Performance Testing Tools

/// Benchmark result
struct BenchmarkResult {
    let name: String
    let iterations: Int
    let totalTime: TimeInterval
    let averageTime: TimeInterval
    let operationsPerSecond: Double
    
    var averageNanoseconds: Double {
        averageTime * 1_000_000_000
    }
}

/// Execute performance benchmark
func benchmark(name: String, iterations: Int, warmup: Int = 100, block: () throws -> Void) rethrows -> BenchmarkResult {
    // Warmup
    for _ in 0..<warmup {
        try block()
    }
    
    // Actual test
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        try block()
    }
    let end = CFAbsoluteTimeGetCurrent()
    
    let totalTime = end - start
    let averageTime = totalTime / Double(iterations)
    let ops = Double(iterations) / totalTime
    
    return BenchmarkResult(
        name: name,
        iterations: iterations,
        totalTime: totalTime,
        averageTime: averageTime,
        operationsPerSecond: ops
    )
}

/// Print results table
func printResults(_ results: [BenchmarkResult]) {
    print("\n" + String(repeating: "=", count: 100))
    print("ULID Performance Benchmark Results")
    print(String(repeating: "=", count: 100))
    print("Test Name                                Iterations      Total(s)    Average(ns) Throughput(ops/s)")
    print(String(repeating: "-", count: 100))
    
    for result in results {
        let name = result.name.padding(toLength: 40, withPad: " ", startingAt: 0)
        let iterations = String(format: "%12d", result.iterations)
        let totalTime = String(format: "%15.6f", result.totalTime)
        let avgNs = String(format: "%15.2f", result.averageNanoseconds)
        let ops = String(format: "%20.0f", result.operationsPerSecond)
        print("\(name) \(iterations) \(totalTime) \(avgNs) \(ops)")
    }
    
    print(String(repeating: "=", count: 100))
    print()
}

// MARK: - Benchmark Suite

func runBenchmarks() {
    var results: [BenchmarkResult] = []
    let iterations = 100_000
    
    print("🚀 Starting performance benchmarks...")
    print("Iterations: \(iterations)")
    print()
    
    // 1. ULID generation test
    print("📊 Test 1: ULID Generation Performance")
    do {
        let result = benchmark(name: "ULID() - Default Constructor", iterations: iterations) {
            _ = ULID()
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 2. Generator test
    print("📊 Test 2: ULIDGenerator Performance")
    do {
        let generator = ULIDGenerator()
        let result = try benchmark(name: "ULIDGenerator.generate()", iterations: iterations) {
            _ = try generator.generate()
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 3. Fixed time generator
    print("📊 Test 3: Fixed Time Generator")
    do {
        let generator = ULIDGenerator(timeProvider: FixedTimeProvider(timestamp: 1000000))
        let result = try benchmark(name: "ULIDGenerator (FixedTime)", iterations: iterations) {
            _ = try generator.generate()
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 4. Batch generation test
    print("📊 Test 4: Batch Generation Performance")
    do {
        let generator = ULIDGenerator()
        let batchSize = 1000
        let batchIterations = iterations / batchSize
        let result = try benchmark(name: "ULIDGenerator.generateBatch(1000)", iterations: batchIterations) {
            _ = try generator.generateBatch(count: batchSize)
        }
        // Adjust to per-ULID average time
        let adjustedResult = BenchmarkResult(
            name: "Batch Generation (per ULID)",
            iterations: iterations,
            totalTime: result.totalTime,
            averageTime: result.averageTime / Double(batchSize),
            operationsPerSecond: result.operationsPerSecond * Double(batchSize)
        )
        results.append(adjustedResult)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 5. String encoding test
    print("📊 Test 5: String Encoding Performance")
    do {
        let ulid = ULID()
        let result = benchmark(name: "ULID.ulidString", iterations: iterations) {
            _ = ulid.ulidString
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 6. String decoding test
    print("📊 Test 6: String Decoding Performance")
    do {
        let string = "01ARZ3NDEKTSV4RRFFQ69G5FAV"
        let result = benchmark(name: "ULID(ulidString:)", iterations: iterations) {
            _ = ULID(ulidString: string)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 7. Data encoding test
    print("📊 Test 7: Data Encoding Performance")
    do {
        let ulid = ULID()
        let result = benchmark(name: "ULID.ulidData", iterations: iterations) {
            _ = ulid.ulidData
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 8. Data decoding test
    print("📊 Test 8: Data Decoding Performance")
    do {
        let data = ULID().ulidData
        let result = benchmark(name: "ULID(ulidData:)", iterations: iterations) {
            _ = ULID(ulidData: data)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 9. Comparison operation test
    print("📊 Test 9: Comparison Performance")
    do {
        let ulid1 = ULID()
        let ulid2 = ULID()
        let result = benchmark(name: "ULID < ULID", iterations: iterations) {
            _ = ulid1 < ulid2
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 10. Equality test
    print("📊 Test 10: Equality Comparison Performance")
    do {
        let ulid1 = ULID()
        let ulid2 = ulid1
        let result = benchmark(name: "ULID == ULID", iterations: iterations) {
            _ = ulid1 == ulid2
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 11. Hash computation test
    print("📊 Test 11: Hash Computation Performance")
    do {
        let ulid = ULID()
        let result = benchmark(name: "ULID.hashValue", iterations: iterations) {
            _ = ulid.hashValue
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 12. Timestamp extraction test
    print("📊 Test 12: Timestamp Extraction Performance")
    do {
        let ulid = ULID()
        let result = benchmark(name: "ULID.timestamp", iterations: iterations) {
            _ = ulid.timestamp
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 13. JSON encoding test
    print("📊 Test 13: JSON Encoding Performance")
    do {
        let ulid = ULID()
        let encoder = JSONEncoder()
        let result = try benchmark(name: "JSONEncoder.encode(ULID)", iterations: iterations / 10) {
            _ = try encoder.encode(ulid)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 14. JSON decoding test
    print("📊 Test 14: JSON Decoding Performance")
    do {
        let json = "\"01ARZ3NDEKTSV4RRFFQ69G5FAV\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        let result = try benchmark(name: "JSONDecoder.decode(ULID)", iterations: iterations / 10) {
            _ = try decoder.decode(ULID.self, from: json)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 15. Sorting test
    print("📊 Test 15: Sorting Performance")
    do {
        let ulids = (0..<1000).map { _ in ULID() }
        let result = benchmark(name: "Array.sorted() - 1000 ULIDs", iterations: 1000) {
            _ = ulids.sorted()
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 16. Concurrent generation test
    print("📊 Test 16: Concurrent Generation Performance")
    do {
        let generator = ULIDGenerator()
        let result = benchmark(name: "Concurrent Generation (8 threads)", iterations: 10000) {
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
                _ = try? generator.generate()
            }
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // UUID Comparison Tests
    print("\n" + String(repeating: "=", count: 100))
    print("UUID vs ULID Performance Comparison")
    print(String(repeating: "=", count: 100))
    
    // 17. UUID generation
    print("📊 Test 17: UUID Generation Performance")
    do {
        let result = benchmark(name: "UUID() - Standard UUID", iterations: iterations) {
            _ = UUID()
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 18. UUID string encoding
    print("📊 Test 18: UUID String Encoding Performance")
    do {
        let uuid = UUID()
        let result = benchmark(name: "UUID.uuidString", iterations: iterations) {
            _ = uuid.uuidString
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 19. UUID string decoding
    print("📊 Test 19: UUID String Decoding Performance")
    do {
        let string = "550E8400-E29B-41D4-A716-446655440000"
        let result = benchmark(name: "UUID(uuidString:)", iterations: iterations) {
            _ = UUID(uuidString: string)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 20. UUID comparison
    print("📊 Test 20: UUID Comparison Performance")
    do {
        let uuid1 = UUID()
        let uuid2 = UUID()
        let result = benchmark(name: "UUID == UUID", iterations: iterations) {
            _ = uuid1 == uuid2
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 21. UUID hash
    print("📊 Test 21: UUID Hash Computation Performance")
    do {
        let uuid = UUID()
        let result = benchmark(name: "UUID.hashValue", iterations: iterations) {
            _ = uuid.hashValue
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }

    // 22. UUID JSON encoding test
    print("📊 Test 22: UUID JSON Encoding Performance")
    do {
        let uuid = UUID()
        let encoder = JSONEncoder()
        let result = try benchmark(name: "JSONEncoder.encode(UUID)", iterations: iterations / 10) {
            _ = try encoder.encode(uuid)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // 23. UUID JSON decoding test
    print("📊 Test 23: UUID JSON Decoding Performance")
    do {
        let json = "\"550E8400-E29B-41D4-A716-446655440000\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        let result = try benchmark(name: "JSONDecoder.decode(UUID)", iterations: iterations / 10) {
            _ = try decoder.decode(UUID.self, from: json)
        }
        results.append(result)
        print("✅ Complete")
    } catch {
        print("❌ Failed: \(error)")
    }
    
    // Print all results
    printResults(results)
    
    // Performance summary
    printSummary(results)
}

func printSummary(_ results: [BenchmarkResult]) {
    print("\n" + String(repeating: "=", count: 100))
    print("Performance Summary")
    print(String(repeating: "=", count: 100))
    
    // Find fastest and slowest operations
    if let fastest = results.min(by: { $0.averageTime < $1.averageTime }) {
        print("⚡️ Fastest Operation: \(fastest.name)")
        print("   Average Time: \(String(format: "%.2f", fastest.averageNanoseconds)) ns")
        print("   Throughput: \(String(format: "%.0f", fastest.operationsPerSecond)) ops/s")
    }
    
    if let slowest = results.max(by: { $0.averageTime < $1.averageTime }) {
        print("\n🐌 Slowest Operation: \(slowest.name)")
        print("   Average Time: \(String(format: "%.2f", slowest.averageNanoseconds)) ns")
        print("   Throughput: \(String(format: "%.0f", slowest.operationsPerSecond)) ops/s")
    }
    
    // ULID vs UUID Direct Comparison
    print("\n" + String(repeating: "=", count: 100))
    print("🆚 ULID vs UUID Performance Comparison")
    print(String(repeating: "=", count: 100))
    
    let comparisons = [
        ("Generation", "ULID() - Default Constructor", "UUID() - Standard UUID"),
        ("String Encoding", "ULID.ulidString", "UUID.uuidString"),
        ("String Decoding", "ULID(ulidString:)", "UUID(uuidString:)"),
        ("Equality", "ULID == ULID", "UUID == UUID"),
        ("Hash", "ULID.hashValue", "UUID.hashValue"),
        ("JSON Encoding", "JSONEncoder.encode(ULID)", "JSONEncoder.encode(UUID)"),
        ("JSON Decoding", "JSONDecoder.decode(ULID)", "JSONDecoder.decode(UUID)")
    ]
    
    for (operation, ulidOp, uuidOp) in comparisons {
        if let ulidResult = results.first(where: { $0.name == ulidOp }),
           let uuidResult = results.first(where: { $0.name == uuidOp }) {
            let speedup = uuidResult.averageTime / ulidResult.averageTime
            let winner = speedup > 1.0 ? "ULID" : "UUID"
            let speedupAbs = abs(speedup)
            
            print("\n\(operation.padding(toLength: 20, withPad: " ", startingAt: 0)):")
            let ulidNs = String(format: "%.2f", ulidResult.averageNanoseconds)
            let ulidOps = String(format: "%.0f", ulidResult.operationsPerSecond)
            let uuidNs = String(format: "%.2f", uuidResult.averageNanoseconds)
            let uuidOps = String(format: "%.0f", uuidResult.operationsPerSecond)
            let speedupStr = String(format: "%.2f", speedupAbs)
            
            print("   ULID: \(ulidNs.padding(toLength: 8, withPad: " ", startingAt: 0)) ns/op  (\(ulidOps.padding(toLength: 10, withPad: " ", startingAt: 0)) ops/s)")
            print("   UUID: \(uuidNs.padding(toLength: 8, withPad: " ", startingAt: 0)) ns/op  (\(uuidOps.padding(toLength: 10, withPad: " ", startingAt: 0)) ops/s)")
            print("   Winner: \(winner) (\(speedupStr)x faster)")
        }
    }
    
    // Key operations summary
    print("\n" + String(repeating: "=", count: 100))
    print("📊 ULID Key Operations Performance:")
    print(String(repeating: "=", count: 100))
    let keyOperations = [
        "ULID() - Default Constructor",
        "ULIDGenerator.generate()",
        "Batch Generation (per ULID)",
        "ULID.ulidString",
        "ULID(ulidString:)",
        "ULID < ULID",
        "ULID == ULID"
    ]
    
    for opName in keyOperations {
        if let result = results.first(where: { $0.name == opName }) {
            let name = opName.padding(toLength: 35, withPad: " ", startingAt: 0)
            let ns = String(format: "%.2f", result.averageNanoseconds)
            let ops = String(format: "%.0f", result.operationsPerSecond)
            print("   \(name): \(ns.padding(toLength: 8, withPad: " ", startingAt: 0)) ns/op  (\(ops.padding(toLength: 10, withPad: " ", startingAt: 0)) ops/s)")
        }
    }
    
    print(String(repeating: "=", count: 100))
    print()
}

// MARK: - Comparison Benchmarks

/// Compare optimized vs original implementation
func runComparisonBenchmarks() {
    print("\n" + String(repeating: "=", count: 100))
    print("Performance Comparison: Optimized vs Original Implementation")
    print(String(repeating: "=", count: 100))
    print()
    
    // Note: This assumes the original implementation is also available
    // Actual usage requires importing the original library module
    
    print("💡 Note: To compare against original yaslab/ULID.swift:")
    print("   1. Add original library as dependency in Package.swift")
    print("   2. Import original module")
    print("   3. Run same tests and compare results")
    print()
    
    // Expected performance improvements (based on design goals)
    print("📈 Expected Performance Improvements:")
    print("   - ULID Generation: 3-5x faster than original")
    print("   - String Encoding: 3-4x faster than original")
    print("   - String Decoding: 3-4x faster than original")
    print("   - Comparison: 8-10x faster (2 vs 16 comparisons)")
    print("   - Hash Computation: 8x faster (2 UInt64 vs 16 UInt8)")
    print("   - Batch Generation: 2-3x faster than individual calls")
    print()
    
    print(String(repeating: "=", count: 100))
    print()
}

// MARK: - System Information

func printSystemInfo() {
    print("\n" + String(repeating: "=", count: 100))
    print("System Information")
    print(String(repeating: "=", count: 100))
    
    #if os(macOS)
    print("OS: macOS")
    #elseif os(iOS)
    print("OS: iOS")
    #elseif os(Linux)
    print("OS: Linux")
    #else
    print("OS: Other")
    #endif
    
    #if swift(>=5.9)
    print("Swift Version: 5.9+")
    #elseif swift(>=5.8)
    print("Swift Version: 5.8+")
    #elseif swift(>=5.7)
    print("Swift Version: 5.7+")
    #else
    print("Swift Version: 5.x")
    #endif
    
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0) ?? "Unknown"
        }
    }
    print("CPU Architecture: \(machine)")
    
    print("Processor Cores: \(ProcessInfo.processInfo.processorCount)")
    print("Physical Memory: \(String(format: "%.2f GB", Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824))")
    
    print(String(repeating: "=", count: 100))
    print()
}

// MARK: - Main Program

print("""
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                  ULID High-Performance Implementation                         ║
║                        Performance Benchmarks                                 ║
║                                                                               ║
║  Test Coverage:                                                               ║
║  • ULID Generation Performance                                                ║
║  • Encoding/Decoding (String, Binary)                                         ║
║  • Comparison and Hash Operations                                             ║
║  • JSON Serialization                                                         ║
║  • Batch and Concurrent Performance                                           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
""")

printSystemInfo()
runBenchmarks()
runComparisonBenchmarks()

print("\n✅ Benchmarks Complete!\n")
