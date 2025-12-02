//
// main.swift
// YaslabComparison
//
// Performance comparison between FastULID and yaslab/ULID.swift
//

import Foundation
import FastULID

typealias FULID = FastULID.ULID

import struct ULID.ULID

// MARK: - Benchmark Framework

struct BenchmarkResult {
    let implementation: String
    let operation: String
    let iterations: Int
    let totalTime: TimeInterval
    let averageNanoseconds: Double
    let throughput: Double
}

func benchmark(implementation: String, operation: String, iterations: Int, warmup: Int = 1000, block: () -> Void) -> BenchmarkResult {
    // Warmup
    for _ in 0..<warmup {
        block()
    }
    
    // Measure
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<iterations {
        block()
    }
    let end = CFAbsoluteTimeGetCurrent()
    
    let totalTime = end - start
    let averageTime = totalTime / Double(iterations)
    let throughput = Double(iterations) / totalTime
    
    return BenchmarkResult(
        implementation: implementation,
        operation: operation,
        iterations: iterations,
        totalTime: totalTime,
        averageNanoseconds: averageTime * 1_000_000_000,
        throughput: throughput
    )
}

// MARK: - Interoperability Test

func testInteroperability() {
    print("🔄 Interoperability Test: FastULID <-> yaslab/ULID.swift")
    print(String(repeating: "=", count: 80))
    
    var allPassed = true
    
    // ========== Test 1: String Input -> Timestamp & Data ==========
    print("\n📝 Test 1: Same String Input -> Compare Timestamp & Data")
    print(String(repeating: "-", count: 80))
    
    let testStrings = [
        "01D0YHEWR9WMPY4NNTPK1MR1TQ",  // yaslab README 示例
        "01ARZ3NDEKTSV4RRFFQ69G5FAV",  // 标准示例
        "00000000000000000000000000",  // 最小值
        "7ZZZZZZZZZZZZZZZZZZZZZZZZZ",  // 最大值
    ]
    
    for str in testStrings {
        guard let fastULID = FULID(ulidString: str),
              let yaslabULID = ULID(ulidString: str) else {
            print("  ❌ Failed to parse: \(str)")
            allPassed = false
            continue
        }
        
        let fastData = fastULID.ulidData
        let yaslabData = yaslabULID.ulidData
        let fastTs = fastULID.timestamp
        let yaslabTs = yaslabULID.timestamp
        
        let dataMatch = fastData == yaslabData
        let tsMatch = abs(fastTs.timeIntervalSince(yaslabTs)) < 0.001
        
        if dataMatch && tsMatch {
            print("  ✅ \(str)")
            print("     Data:      \(fastData.map { String(format: "%02X", $0) }.joined())")
            print("     Timestamp: \(fastTs)")
        } else {
            print("  ❌ \(str)")
            if !dataMatch {
                print("     FastULID Data:  \(fastData.map { String(format: "%02X", $0) }.joined())")
                print("     yaslab Data:    \(yaslabData.map { String(format: "%02X", $0) }.joined())")
            }
            if !tsMatch {
                print("     FastULID Timestamp: \(fastTs)")
                print("     yaslab Timestamp:   \(yaslabTs)")
            }
            allPassed = false
        }
    }
    
    // ========== Test 2: Data Input -> Timestamp & String ==========
    print("\n📦 Test 2: Same Data Input -> Compare Timestamp & String")
    print(String(repeating: "-", count: 80))
    
    let testDataSets: [(name: String, data: Data)] = [
        ("Zero", Data(repeating: 0x00, count: 16)),
        ("Max", Data(repeating: 0xFF, count: 16)),
        ("Example", Data([0x01, 0x68, 0x3D, 0x17, 0x73, 0x09, 0xE5, 0x2D, 
                          0xE2, 0x56, 0xBA, 0xB4, 0xC3, 0x4C, 0x07, 0x57])),
    ]
    
    for (name, data) in testDataSets {
        guard let fastULID = FULID(ulidData: data),
              let yaslabULID = ULID(ulidData: data) else {
            print("  ❌ Failed to create from data: \(name)")
            allPassed = false
            continue
        }
        
        let fastStr = fastULID.ulidString
        let yaslabStr = yaslabULID.ulidString
        let fastTs = fastULID.timestamp
        let yaslabTs = yaslabULID.timestamp
        
        let strMatch = fastStr == yaslabStr
        let tsMatch = abs(fastTs.timeIntervalSince(yaslabTs)) < 0.001
        
        if strMatch && tsMatch {
            print("  ✅ \(name)")
            print("     String:    \(fastStr)")
            print("     Timestamp: \(fastTs)")
        } else {
            print("  ❌ \(name)")
            if !strMatch {
                print("     FastULID String: \(fastStr)")
                print("     yaslab String:   \(yaslabStr)")
            }
            if !tsMatch {
                print("     FastULID Timestamp: \(fastTs)")
                print("     yaslab Timestamp:   \(yaslabTs)")
            }
            allPassed = false
        }
    }
    
    // ========== Test 3: Round-trip Test ==========
    print("\n🔁 Test 3: Round-trip (FastULID -> String -> yaslab -> Data -> FastULID)")
    print(String(repeating: "-", count: 80))
    
    for i in 1...5 {
        let original = FULID()
        let str = original.ulidString
        
        guard let yaslabFromStr = ULID(ulidString: str) else {
            print("  ❌ Sample \(i): yaslab failed to parse FastULID string")
            allPassed = false
            continue
        }
        
        let yaslabData = yaslabFromStr.ulidData
        
        guard let fastFromYaslabData = FULID(ulidData: yaslabData) else {
            print("  ❌ Sample \(i): FastULID failed to parse yaslab data")
            allPassed = false
            continue
        }
        
        if original == fastFromYaslabData {
            print("  ✅ Sample \(i): \(str) -> round-trip OK")
        } else {
            print("  ❌ Sample \(i): Round-trip mismatch")
            print("     Original:  \(original.ulidString)")
            print("     After:     \(fastFromYaslabData.ulidString)")
            allPassed = false
        }
    }
    
    // ========== Summary ==========
    print()
    if allPassed {
        print("🎉 All interoperability tests passed!")
    } else {
        print("⚠️ Some interoperability tests failed!")
    }
    print()
}

// MARK: - Legacy Consistency Test (kept for backward compatibility)

func testDataConsistency() {
    print("🔍 Data Consistency Test")
    print(String(repeating: "-", count: 80))
    
    // 使用 yaslab 标准示例
    let testStrings = [
        "01D0YHEWR9WMPY4NNTPK1MR1TQ",  // yaslab README 示例
        "00000000000000000000000000",  // 最小值
        "7ZZZZZZZZZZZZZZZZZZZZZZZZZ",  // 最大值
    ]
    
    var allPassed = true
    
    for str in testStrings {
        guard let fastULID = FULID(ulidString: str),
              let yaslabULID = ULID(ulidString: str) else {
            print("  ❌ Failed to parse: \(str)")
            allPassed = false
            continue
        }
        
        let fastData = fastULID.ulidData
        let yaslabData = yaslabULID.ulidData
        
        if fastData == yaslabData {
            print("  ✅ \(str)")
            print("     Data: \(fastData.map { String(format: "%02X", $0) }.joined())")
        } else {
            print("  ❌ \(str)")
            print("     FastULID:  \(fastData.map { String(format: "%02X", $0) }.joined())")
            print("     yaslab:    \(yaslabData.map { String(format: "%02X", $0) }.joined())")
            allPassed = false
        }
        
        // 验证时间戳一致
        let fastTs = fastULID.timestamp
        let yaslabTs = yaslabULID.timestamp
        if abs(fastTs.timeIntervalSince(yaslabTs)) < 0.001 {
            print("     Timestamp: ✅ match")
        } else {
            print("     Timestamp: ❌ FastULID=\(fastTs), yaslab=\(yaslabTs)")
            allPassed = false
        }
    }
    
    // 随机生成测试
    print()
    print("  Random generation consistency (5 samples):")
    for i in 1...5 {
        let fast = FULID()
        let fastStr = fast.ulidString
        
        // 用 FastULID 生成的字符串让 yaslab 解析
        if let yaslab = ULID(ulidString: fastStr) {
            let fastData = fast.ulidData
            let yaslabData = yaslab.ulidData
            
            if fastData == yaslabData {
                print("  ✅ Sample \(i): \(fastStr)")
            } else {
                print("  ❌ Sample \(i): Data mismatch")
                allPassed = false
            }
        } else {
            print("  ❌ Sample \(i): yaslab failed to parse FastULID string")
            allPassed = false
        }
    }
    
    print()
    if allPassed {
        print("  🎉 All consistency tests passed!")
    } else {
        print("  ⚠️ Some consistency tests failed!")
    }
    print()
}

// MARK: - Main Comparison

print("""
╔════════════════════════════════════════════════════════════════════════════════╗
║                                                                                ║
║         FastULID vs yaslab/ULID.swift Performance Comparison                   ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝

""")

// Run interoperability test first
testInteroperability()

var results: [BenchmarkResult] = []
let iterations = 100_000

// Test 1: Generation
print("📊 Test 1: ID Generation (\(iterations) iterations)")
print(String(repeating: "-", count: 80))

let r1 = benchmark(implementation: "FastULID", operation: "Generation", iterations: iterations) {
    _ = FULID()
}
results.append(r1)
print("  ✅ FastULID:          \(String(format: "%8.2f", r1.averageNanoseconds)) ns/op  (\(String(format: "%10.0f", r1.throughput)) ops/s)")

let r2 = benchmark(implementation: "yaslab/ULID.swift", operation: "Generation", iterations: iterations) {
    _ = ULID()
}
results.append(r2)
print("  📦 yaslab/ULID.swift: \(String(format: "%8.2f", r2.averageNanoseconds)) ns/op  (\(String(format: "%10.0f", r2.throughput)) ops/s)")
let speedup1 = r2.averageNanoseconds / r1.averageNanoseconds
print("  ⚡️ Speedup: \(String(format: "%.2fx", speedup1)) faster")

print()

// Test 2: String Encoding
print("📊 Test 2: String Encoding (\(iterations) iterations)")
print(String(repeating: "-", count: 80))

let fastULID = FULID()
let r3 = benchmark(implementation: "FastULID", operation: "String Encoding", iterations: iterations) {
    _ = fastULID.ulidString
}
results.append(r3)
print("  ✅ FastULID:          \(String(format: "%8.2f", r3.averageNanoseconds)) ns/op")

let yaslabULID = ULID()
let r4 = benchmark(implementation: "yaslab/ULID.swift", operation: "String Encoding", iterations: iterations) {
    _ = yaslabULID.ulidString
}
results.append(r4)
print("  📦 yaslab/ULID.swift: \(String(format: "%8.2f", r4.averageNanoseconds)) ns/op")
let speedup2 = r4.averageNanoseconds / r3.averageNanoseconds
print("  ⚡️ Speedup: \(String(format: "%.2fx", speedup2)) faster")

print()

// Test 3: String Decoding
print("📊 Test 3: String Decoding (\(iterations) iterations)")
print(String(repeating: "-", count: 80))

let fastULIDString = fastULID.ulidString
let r5 = benchmark(implementation: "FastULID", operation: "String Decoding", iterations: iterations) {
    _ = FULID(ulidString: fastULIDString)
}
results.append(r5)
print("  ✅ FastULID:          \(String(format: "%8.2f", r5.averageNanoseconds)) ns/op")

let yaslabString = yaslabULID.ulidString
let r6 = benchmark(implementation: "yaslab/ULID.swift", operation: "String Decoding", iterations: iterations) {
    _ = ULID(ulidString: yaslabString)
}
results.append(r6)
print("  📦 yaslab/ULID.swift: \(String(format: "%8.2f", r6.averageNanoseconds)) ns/op")
let speedup3 = r6.averageNanoseconds / r5.averageNanoseconds
print("  ⚡️ Speedup: \(String(format: "%.2fx", speedup3)) faster")

print()

// Test 4: Timestamp Extraction
print("📊 Test 4: Timestamp Extraction (\(iterations) iterations)")
print(String(repeating: "-", count: 80))

let r7 = benchmark(implementation: "FastULID", operation: "Timestamp", iterations: iterations) {
    _ = fastULID.timestamp
}
results.append(r7)
print("  ✅ FastULID:          \(String(format: "%8.2f", r7.averageNanoseconds)) ns/op")

let r8 = benchmark(implementation: "yaslab/ULID.swift", operation: "Timestamp", iterations: iterations) {
    _ = yaslabULID.timestamp
}
results.append(r8)
print("  📦 yaslab/ULID.swift: \(String(format: "%8.2f", r8.averageNanoseconds)) ns/op")
let speedup4 = r8.averageNanoseconds / r7.averageNanoseconds
print("  ⚡️ Speedup: \(String(format: "%.2fx", speedup4)) faster")

print()

// Test 5: Data Encoding
print("📊 Test 5: Data Encoding (\(iterations) iterations)")
print(String(repeating: "-", count: 80))

let r9 = benchmark(implementation: "FastULID", operation: "Data Encoding", iterations: iterations) {
    _ = fastULID.ulidData
}
results.append(r9)
print("  ✅ FastULID:          \(String(format: "%8.2f", r9.averageNanoseconds)) ns/op")

let r10 = benchmark(implementation: "yaslab/ULID.swift", operation: "Data Encoding", iterations: iterations) {
    _ = yaslabULID.ulidData
}
results.append(r10)
print("  📦 yaslab/ULID.swift: \(String(format: "%8.2f", r10.averageNanoseconds)) ns/op")
let speedup5 = r10.averageNanoseconds / r9.averageNanoseconds
print("  ⚡️ Speedup: \(String(format: "%.2fx", speedup5)) faster")

print()

// Test 6: Batch Generation (FastULID only feature)
print("📊 Test 6: Batch Generation - FastULID Only Feature")
print(String(repeating: "-", count: 80))

let generator = ULIDGenerator()
let r11 = benchmark(implementation: "FastULID", operation: "Batch Generation", iterations: 100) {
    _ = try? generator.generateBatch(count: 1000)
}
let perIDCost = r11.averageNanoseconds / 1000.0
print("  ✅ FastULID Batch:    \(String(format: "%8.2f", perIDCost)) ns/ID  (batch of 1000)")
print("  💡 Batch is \(String(format: "%.1fx", r1.averageNanoseconds / perIDCost)) faster than single generation")

print()

// Print Summary
print(String(repeating: "=", count: 80))
print("📊 Performance Summary")
print(String(repeating: "=", count: 80))
print()
print("Operation                      FastULID          yaslab    Speedup")
print(String(repeating: "-", count: 80))

let operations = ["Generation", "String Encoding", "String Decoding", "Timestamp", "Data Encoding"]
for op in operations {
    if let fast = results.first(where: { $0.implementation == "FastULID" && $0.operation == op }),
       let yaslab = results.first(where: { $0.implementation == "yaslab/ULID.swift" && $0.operation == op }) {
        let speedup = yaslab.averageNanoseconds / fast.averageNanoseconds
        let opPad = op.padding(toLength: 25, withPad: " ", startingAt: 0)
        let fastStr = String(format: "%8.2f ns", fast.averageNanoseconds)
        let yaslabStr = String(format: "%8.2f ns", yaslab.averageNanoseconds)
        let speedupStr = String(format: "%6.2fx", speedup)
        print("\(opPad) \(fastStr)    \(yaslabStr)    \(speedupStr)")
    }
}

print(String(repeating: "=", count: 80))

print("""

╔════════════════════════════════════════════════════════════════════════════════╗
║  ✅ Benchmark Complete!                                                        ║
║                                                                                ║
║  FastULID Optimizations:                                                       ║
║  • UInt64 pair storage (vs 16-byte tuple)                                     ║
║  • Optimized Base32 with lookup tables                                        ║
║  • Platform-specific lock optimization                                         ║
║  • Batch generation support                                                    ║
║  • Inlined critical path functions                                             ║
╚════════════════════════════════════════════════════════════════════════════════╝

""")
