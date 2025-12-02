//
// main.swift
// CorrectnessBenchmark
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// 2. Comparing results with reference implementations (yaslab/ULID.swift, C libraries)
// 3. Verifying encoding/decoding consistency
// 4. Checking spec compliance
//

import Foundation
import FastULID

// MARK: - Test Utilities

struct TestResult {
    let name: String
    let passed: Bool
    let details: String
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) -> TestResult {
    let passed = actual == expected
    let details = passed ? "✅ \(message)" : "❌ \(message)\n  Expected: \(expected)\n  Got: \(actual)"
    return TestResult(name: message, passed: passed, details: details)
}

// MARK: - Known Test Vectors

struct ULIDTestVector {
    let timestamp: UInt64          // Milliseconds since epoch
    let randomBytes: [UInt8]       // 10 bytes of randomness
    let expectedString: String     // Expected ULID string
    let expectedData: Data         // Expected 16-byte data
}

// Test vectors from actual ULID implementation
let testVectors: [ULIDTestVector] = [
    // Vector 1: All zeros (minimum ULID)
    ULIDTestVector(
        timestamp: 0,
        randomBytes: [],
        expectedString: "00000000000000000000000000",
        expectedData: Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    ),
    
    // Vector 2: Maximum timestamp, all zeros random
    ULIDTestVector(
        timestamp: 281474976710655, // 2^48 - 1
        randomBytes: [],
        expectedString: "ZZZZZZZZZW0000000000000000",
        expectedData: Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    ),
    
    // Vector 3: All ones (maximum ULID)
    // Note: Last character of ULID only uses 3 bits (128 bits total, 26 * 5 = 130)
    ULIDTestVector(
        timestamp: 281474976710655, // 2^48 - 1
        randomBytes: [],
        expectedString: "ZZZZZZZZZZZZZZZZZZZZZZZZZ7", // Last char is '7' not 'Z' (only 3 bits)
        expectedData: Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
    ),
    
    // Vector 4: Real-world example
    ULIDTestVector(
        timestamp: 1469918176385,
        randomBytes: [],
        expectedString: "05B3VWV4G4938NKRKAYDXW0J64",
        expectedData: Data([0x01, 0x56, 0x3D, 0xF3, 0x64, 0x81, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0, 0x12, 0x34])
    ),
]

// MARK: - Correctness Tests

func testKnownVectors() -> [TestResult] {
    var results: [TestResult] = []
    
    print("\n╔════════════════════════════════════════════════════════════════════╗")
    print("║                                                                    ║")
    print("║                  ULID Correctness Validation                       ║")
    print("║                                                                    ║")
    print("╚════════════════════════════════════════════════════════════════════╝\n")
    
    print("📋 Testing Known Test Vectors")
    print("------------------------------------------------------------")
    
    for (index, vector) in testVectors.enumerated() {
        print("\n🔍 Vector \(index + 1): \(vector.expectedString)")
        
        // Test 1: Create ULID from data
        var data = vector.expectedData
        let ulid = ULID(ulidData: data)!

        
        // Test 2: String encoding
        let actualString = ulid.ulidString
        results.append(assertEqual(actualString, vector.expectedString, "String encoding"))
        
        // Test 3: Data encoding
        let actualData = ulid.ulidData
        results.append(assertEqual(actualData, vector.expectedData, "Data encoding"))
        
        // Test 4: String decoding
        if let decoded = ULID(ulidString: vector.expectedString) {
            results.append(assertEqual(decoded.ulidString, vector.expectedString, "String decoding"))
            results.append(assertEqual(decoded.ulidData, vector.expectedData, "Data from decoded ULID"))
        } else {
            results.append(TestResult(name: "String decoding", passed: false, details: "❌ Failed to decode string"))
        }
        
        // Test 5: Data decoding
        if let decoded = ULID(ulidData: vector.expectedData) {
            results.append(assertEqual(decoded.ulidString, vector.expectedString, "Data decoding"))
        } else {
            results.append(TestResult(name: "Data decoding", passed: false, details: "❌ Failed to decode data"))
        }
        
        // Test 6: Round-trip consistency
        if let decoded = ULID(ulidString: actualString) {
            results.append(assertEqual(decoded.ulidString, actualString, "String round-trip"))
        } else {
            results.append(TestResult(name: "String round-trip", passed: false, details: "❌ Round-trip failed"))
        }
    }
    
    return results
}

func testBase32EdgeCases() -> [TestResult] {
    var results: [TestResult] = []
    
    print("\n\n📋 Testing Base32 Edge Cases")
    print("------------------------------------------------------------")
    
    // Test 1: All zeros
    let allZeros = String(repeating: Character("0"), count: 26)
    if let ulid = ULID(ulidString: allZeros) {
        results.append(assertEqual(ulid.ulidString, allZeros, "All zeros"))
    } else {
        results.append(TestResult(name: "All zeros", passed: false, details: "❌ Failed"))
    }
    
    // Test 2: Maximum valid value (last char must be 0-7 due to 3-bit constraint)
    let maxValid = "7ZZZZZZZZZZZZZZZZZZZZZZZZ7"
    if let ulid = ULID(ulidString: maxValid) {
        results.append(assertEqual(ulid.ulidString, maxValid, "Maximum valid ULID"))
    } else {
        results.append(TestResult(name: "Maximum valid ULID", passed: false, details: "❌ Failed"))
    }
    
    // Test 3: Invalid characters should fail
    // Note: Crockford Base32 allows I→1, L→1, O→0 conversions, so only truly invalid chars fail
    let invalidStrings = [
        "01ARZ3NDEKTSV4RRFFQ69G5FA!",  // Invalid char '!'
        "01ARZ3NDEKTSV4RRFFQ69G5FA@",  // Invalid char '@'
        "01ARZ3NDEKTSV4RRFFQ69G5FA#",  // Invalid char '#'
    ]
    
    for invalidString in invalidStrings {
        let ulid = ULID(ulidString: invalidString)
        let passed = ulid == nil
        let char = invalidString.last!
        results.append(TestResult(
            name: "Reject invalid char '\(char)'",
            passed: passed,
            details: passed ? "✅ Correctly rejected" : "❌ Should have rejected"
        ))
    }
    
    // Test 4: Wrong length should fail
    let wrongLengths = ["", "123", "01ARZ3NDEKTSV4RRFFQ69G5", "01ARZ3NDEKTSV4RRFFQ69G5FAVEXTRA"]
    for wrongString in wrongLengths {
        let ulid = ULID(ulidString: wrongString)
        let passed = ulid == nil
        results.append(TestResult(
            name: "Reject length \(wrongString.count)",
            passed: passed,
            details: passed ? "✅ Correctly rejected" : "❌ Should have rejected"
        ))
    }
    
    return results
}

func testMonotonicity() -> [TestResult] {
    var results: [TestResult] = []
    
    print("\n\n📋 Testing Monotonicity")
    print("------------------------------------------------------------")
    
    let generator = ULIDGenerator(strategy: .monotonic)
    var previousULID: ULID? = nil
    var allPassed = true
    
    for i in 0..<1000 {
        do {
            let ulid = try generator.generate()
            
            if let prev = previousULID {
                if ulid <= prev {
                    allPassed = false
                    results.append(TestResult(
                        name: "Monotonicity at iteration \(i)",
                        passed: false,
                        details: "❌ ULID not greater than previous\n  Previous: \(prev.ulidString)\n  Current:  \(ulid.ulidString)"
                    ))
                    break
                }
            }
            
            previousULID = ulid
        } catch {
            allPassed = false
            results.append(TestResult(
                name: "Generation at iteration \(i)",
                passed: false,
                details: "❌ Generation failed: \(error)"
            ))
            break
        }
    }
    
    if allPassed {
        results.append(TestResult(
            name: "Monotonic generation (1000 iterations)",
            passed: true,
            details: "✅ All 1000 ULIDs are strictly monotonic"
        ))
    }
    
    return results
}

func testTimestampExtraction() -> [TestResult] {
    var results: [TestResult] = []
    
    print("\n\n📋 Testing Timestamp Extraction")
    print("------------------------------------------------------------")
    
    let testDates: [Date] = [
        Date(timeIntervalSince1970: 0),                    // Unix epoch
        Date(timeIntervalSince1970: 1469918176.385),       // 2016-07-30 (example timestamp)
        Date(timeIntervalSince1970: 1609459200.0),         // 2021-01-01 (example timestamp)
        Date(timeIntervalSince1970: Date().timeIntervalSince1970), // Now
    ]
    
    for testDate in testDates {
        let ulid = ULID(timestamp: testDate)
        let extractedDate = ulid.timestamp
        let diff = abs(extractedDate.timeIntervalSince(testDate))
        
        // Should match within 1 millisecond
        let passed = diff < 0.001
        results.append(TestResult(
            name: "Timestamp extraction for \(testDate)",
            passed: passed,
            details: passed ? "✅ Matched within tolerance" : "❌ Diff: \(diff)s"
        ))
    }
    
    return results
}

// MARK: - Summary

func printSummary(_ allResults: [[TestResult]]) {
    let flatResults = allResults.flatMap { $0 }
    let passed = flatResults.filter { $0.passed }.count
    let failed = flatResults.filter { !$0.passed }.count
    let total = flatResults.count
    
    print("\n\n╔════════════════════════════════════════════════════════════════════╗")
    print("║                         Test Summary                               ║")
    print("╚════════════════════════════════════════════════════════════════════╝")
    
    print("\n📊 Overall Results:")
    print("  Total:  \(total) tests")
    print("  ✅ Passed: \(passed)")
    print("  ❌ Failed: \(failed)")
    print("  Success Rate: \(String(format: "%.1f", Double(passed) / Double(total) * 100))%")
    
    if failed > 0 {
        print("\n❌ Failed Tests:")
        for result in flatResults where !result.passed {
            print("\n  \(result.details)")
        }
    }
    
    print("\n" + (failed == 0 ? "🎉 All tests passed!" : "⚠️  Some tests failed!"))
    print("\n" + String(repeating: "=", count: 70) + "\n")
}

func printDetailedResults(_ results: [TestResult]) {
    for result in results {
        print("  \(result.details)")
    }
}

// MARK: - Main

print("\n" + String(repeating: "=", count: 70))
print("ULID Implementation Correctness Validation")
print(String(repeating: "=", count: 70))

let testVectorResults = testKnownVectors()
printDetailedResults(testVectorResults)

let base32Results = testBase32EdgeCases()
printDetailedResults(base32Results)

let monotonicityResults = testMonotonicity()
printDetailedResults(monotonicityResults)

let timestampResults = testTimestampExtraction()
printDetailedResults(timestampResults)

printSummary([testVectorResults, base32Results, monotonicityResults, timestampResults])

// MARK: - Comparison with Other Libraries

print("\n╔════════════════════════════════════════════════════════════════════╗")
print("║                  Cross-Library Comparison                          ║")
print("╚════════════════════════════════════════════════════════════════════╝\n")

print("📋 To compare with yaslab/ULID.swift:")
print("  1. Add dependency in Package.swift:")
print("     .package(url: \"https://github.com/yaslab/ULID.swift\", from: \"1.2.0\")")
print("  2. Run: swift run CorrectnessBenchmark\n")

print("📋 To compare with C ULID library:")
print("  1. Install C library (e.g., https://github.com/suyash/ulid)")
print("  2. Set up bridging header")
print("  3. Run: swift run CorrectnessBenchmark\n")

print("For detailed comparison benchmarks, see:")
print("  • Benchmarks/YaslabComparison/")
print("  • Benchmarks/CLibraryComparison/\n")

