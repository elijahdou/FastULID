//
// ULIDTests.swift
// FastULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//

import XCTest
@testable import FastULID

final class ULIDTests: XCTestCase {
    
    // MARK: Basic Functionality Tests
    
    func testBasicGeneration() throws {
        let ulid = ULID()
        
        // Verify string length
        XCTAssertEqual(ulid.ulidString.count, 26, "ULID string should be 26 characters")
        
        // Verify data length
        XCTAssertEqual(ulid.ulidData.count, 16, "ULID data should be 16 bytes")
        
        // Verify timestamp is within reasonable range
        let now = Date()
        let timeDiff = abs(ulid.timestamp.timeIntervalSince(now))
        XCTAssertLessThan(timeDiff, 0.1, "Timestamp should be close to current time")
    }
    
    func testInitFromString() throws {
        // Note: Last character must be 0-7 (only 3 bits used in ULID)
        let ulidString = "01ARZ3NDEKTSV4RRFFQ69G5FA3"
        let ulid = ULID(ulidString: ulidString)
        
        XCTAssertNotNil(ulid, "Should be able to create ULID from valid string")
        XCTAssertEqual(ulid?.ulidString, ulidString, "String should match")
    }
    
    func testInvalidString() throws {
        // Wrong length
        XCTAssertNil(ULID(ulidString: "123"), "Too short string should return nil")
        XCTAssertNil(ULID(ulidString: "01ARZ3NDEKTSV4RRFFQ69G5FAVEXTRA"), "Too long string should return nil")
        
        // Contains invalid characters
        XCTAssertNil(ULID(ulidString: "01ARZ3NDEKTSV4RRFFQ69G5FA!"), "Invalid characters should return nil")
    }
    
    func testInitFromData() throws {
        let ulid1 = ULID()
        let data = ulid1.ulidData
        
        let ulid2 = ULID(ulidData: data)
        XCTAssertNotNil(ulid2, "Should be able to create ULID from valid data")
        XCTAssertEqual(ulid1, ulid2, "ULID created from data should be equal")
    }
    
    func testInitWithTimestamp() throws {
        let date = Date(timeIntervalSince1970: 1234567890.123)
        let ulid = ULID(timestamp: date)
        
        let diff = abs(ulid.timestamp.timeIntervalSince(date))
        XCTAssertLessThan(diff, 0.001, "Timestamp should preserve millisecond precision")
    }
    
    // MARK: Sorting Tests
    
    func testMonotonicOrdering() throws {
        // Use ULIDGenerator with monotonic strategy to guarantee ordering
        let generator = ULIDGenerator(strategy: .monotonic)
        var ulids = [ULID]()
        for _ in 0..<100 {
            if let ulid = try? generator.generate() {
                ulids.append(ulid)
            }
            // Small delay to ensure different timestamps
            usleep(100)
        }
        
        // Verify each ULID is greater than the previous one
        for i in 1..<ulids.count {
            XCTAssertLessThan(ulids[i-1], ulids[i], "ULID should be monotonically increasing")
        }
    }
    
    func testSortStability() throws {
        let ulids = (0..<100).map { _ in ULID() }
        let sorted = ulids.sorted()
        
        // Verify sorted order remains increasing
        for i in 1..<sorted.count {
            XCTAssertLessThanOrEqual(sorted[i-1], sorted[i], "Sorting should maintain order")
        }
    }
    
    // MARK: Comparison Tests
    
    func testEquality() throws {
        let ulid1 = ULID()
        let data = ulid1.ulidData
        let ulid2 = ULID(ulidData: data)!
        
        XCTAssertEqual(ulid1, ulid2, "ULIDs with same data should be equal")
        XCTAssertEqual(ulid1.hashValue, ulid2.hashValue, "Hash values should be equal")
    }
    
    func testInequality() throws {
        let ulid1 = ULID()
        usleep(1000)
        let ulid2 = ULID()
        
        XCTAssertNotEqual(ulid1, ulid2, "Different ULIDs should not be equal")
    }
    
    func testComparisonOperators() throws {
        let ulid1 = ULID(timestamp: Date(timeIntervalSince1970: 1000))
        let ulid2 = ULID(timestamp: Date(timeIntervalSince1970: 2000))
        
        XCTAssertLessThan(ulid1, ulid2, "Earlier ULID should be less than later")
        XCTAssertGreaterThan(ulid2, ulid1, "Later ULID should be greater than earlier")
        XCTAssertLessThanOrEqual(ulid1, ulid1, "ULID should be less than or equal to itself")
        XCTAssertGreaterThanOrEqual(ulid1, ulid1, "ULID should be greater than or equal to itself")
    }
    
    // MARK: Encoding/Decoding Tests
    
    func testBase32Encoding() throws {
        let ulid = ULID()
        let string = ulid.ulidString
        
        // Verify contains only valid characters
        let validChars = CharacterSet(charactersIn: "0123456789ABCDEFGHJKMNPQRSTVWXYZ")
        XCTAssertTrue(string.unicodeScalars.allSatisfy { validChars.contains($0) },
                     "ULID string should only contain Base32 characters")
    }
    
    func testBase32Decoding() throws {
        let testCases = [
            "00000000000000000000000000",  // Minimum value (all zeros)
            "7ZZZZZZZZZZZZZZZZZZZZZZZZZ",  // Maximum value (first char max 7, rest all Z)
            "01ARZ3NDEKTSV4RRFFQ69G5FAV",  // Example value
        ]
        
        for string in testCases {
            let ulid = ULID(ulidString: string)
            XCTAssertNotNil(ulid, "Should be able to decode string: \(string)")
            XCTAssertEqual(ulid?.ulidString, string, "Encoding/decoding should be reversible")
        }
        
        // Test invalid first character (must be 0-7)
        let invalidULID = ULID(ulidString: "8ZZZZZZZZZZZZZZZZZZZZZZZZZ")
        XCTAssertNil(invalidULID, "First character > 7 should be rejected")
    }
    
    func testEncodingRoundTrip() throws {
        for _ in 0..<100 {
            let ulid1 = ULID()
            let string = ulid1.ulidString
            let ulid2 = ULID(ulidString: string)
            
            XCTAssertNotNil(ulid2, "Should be able to decode from encoded string")
            XCTAssertEqual(ulid1, ulid2, "Encoding round trip should be consistent")
        }
    }
    
    // MARK: JSON Encoding/Decoding Tests
    
    func testJSONEncoding() throws {
        // Note: Last character must be 0-7 (only 3 bits used in ULID)
        let ulid = ULID(ulidString: "01ARZ3NDEKTSV4RRFFQ69G5FA3")!
        let encoder = JSONEncoder()
        let data = try encoder.encode(ulid)
        let string = String(data: data, encoding: .utf8)
        
        XCTAssertNotNil(string)
        XCTAssertTrue(string!.contains("01ARZ3NDEKTSV4RRFFQ69G5FA3"), "JSON should contain ULID string")
    }
    
    func testJSONDecoding() throws {
        // Note: Last character must be 0-7 (only 3 bits used in ULID)
        let json = "\"01ARZ3NDEKTSV4RRFFQ69G5FA3\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let ulid = try decoder.decode(ULID.self, from: data)
        
        XCTAssertEqual(ulid.ulidString, "01ARZ3NDEKTSV4RRFFQ69G5FA3")
    }
    
    func testJSONRoundTrip() throws {
        let ulid1 = ULID()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(ulid1)
        let ulid2 = try decoder.decode(ULID.self, from: data)
        
        XCTAssertEqual(ulid1, ulid2, "JSON encoding round trip should be consistent")
    }
    
    // MARK: UUID Conversion Tests
    
    func testUUIDConversion() throws {
        let ulid1 = ULID()
        let uuid = UUID(uuid: ulid1.ulid)
        let ulid2 = ULID(ulid: uuid.uuid)
        
        XCTAssertEqual(ulid1, ulid2, "ULID and UUID conversion should be consistent")
    }
    
    // MARK: Batch Generation Tests
    
    func testBatchGeneration() throws {
        let count = 1000
        let generator = ULIDGenerator()
        let ulids = try generator.generateBatch(count: count)
        
        XCTAssertEqual(ulids.count, count, "Should generate specified number of ULIDs")
        
        // Verify all ULIDs are unique
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, count, "All ULIDs should be unique")
    }
    
    func testBatchGenerationOrdering() throws {
        let generator = ULIDGenerator(strategy: .monotonic)
        let ulids = try generator.generateBatch(count: 100)
        
        // Verify monotonic increasing
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "Batch generated ULIDs should be monotonic")
        }
    }
    
    // MARK: Timestamp Tests
    
    func testTimestampExtraction() throws {
        let date = Date(timeIntervalSince1970: 1234567890.123)
        let ulid = ULID(timestamp: date)
        
        let extractedTime = ulid.timestamp
        let diff = abs(extractedTime.timeIntervalSince(date))
        
        XCTAssertLessThan(diff, 0.001, "Extracted timestamp should match original (millisecond precision)")
    }
    
    func testTimestampMilliseconds() throws {
        let date = Date(timeIntervalSince1970: 1234567890.123)
        let ulid = ULID(timestamp: date)
        
        let expectedMs = UInt64(1234567890123)
        XCTAssertEqual(ulid.timestampMilliseconds, expectedMs, "Timestamp milliseconds should be correct")
    }
    
    // MARK: Edge Case Tests
    
    func testMinValue() throws {
        let minString = "00000000000000000000000000"
        let ulid = ULID(ulidString: minString)
        
        XCTAssertNotNil(ulid)
        XCTAssertEqual(ulid?.ulidString, minString)
    }
    
    func testMaxValue() throws {
        // ULID is 128 bits encoded as 26 Base32 chars
        // Standard ULID spec: first char only has 3 bits valid (0-7)
        // Maximum ULID: first char = 7, rest = Z
        let maxString = "7ZZZZZZZZZZZZZZZZZZZZZZZZZ"
        let ulid = ULID(ulidString: maxString)
        
        XCTAssertNotNil(ulid, "Should be able to parse max ULID")
        XCTAssertEqual(ulid?.ulidString, maxString, "Max ULID string should match")
        
        // Verify all bytes are 0xFF
        guard let ulidData = ulid?.ulidData else {
            XCTFail("ULID data should not be nil")
            return
        }
        
        XCTAssertEqual(ulidData.count, 16, "ULID data should be 16 bytes")
        
        for i in 0..<16 {
            XCTAssertEqual(ulidData[i], 0xFF, "Byte \(i) should be 0xFF")
        }
    }
    
    // MARK: Concurrency Tests
    
    func testConcurrentGeneration() throws {
        let expectation = XCTestExpectation(description: "Concurrent ULID generation")
        let count = 1000
        var ulids: [ULID] = []
        var lock = os_unfair_lock()
        
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            let ulid = ULID()
            os_unfair_lock_lock(&lock)
            ulids.append(ulid)
            os_unfair_lock_unlock(&lock)
        }
        
        // Verify all ULIDs are unique
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, count, "Concurrent ULIDs should all be unique")
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: Performance Tests
    
    func testGenerationPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = ULID()
            }
        }
    }
    
    func testStringEncodingPerformance() throws {
        let ulid = ULID()
        measure {
            for _ in 0..<1000 {
                _ = ulid.ulidString
            }
        }
    }
    
    func testStringDecodingPerformance() throws {
        let string = "01ARZ3NDEKTSV4RRFFQ69G5FAV"
        measure {
            for _ in 0..<1000 {
                _ = ULID(ulidString: string)
            }
        }
    }
    
    func testComparisonPerformance() throws {
        let ulids = (0..<100).map { _ in ULID() }
        measure {
            _ = ulids.sorted()
        }
    }
}
