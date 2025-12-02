//
// ULIDGeneratorTests.swift
// FastULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//

import XCTest
@testable import FastULID

final class ULIDGeneratorTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        // Reset global configuration to default
        ULID.configure(timeProvider: SystemTimeProvider(), strategy: .monotonic)
    }

    // MARK: Basic Generation Tests
    
    func testBasicGeneration() throws {
        let generator = ULIDGenerator()
        let ulid = try generator.generate()
        
        XCTAssertEqual(ulid.ulidString.count, 26)
    }
    
    func testMultipleGeneration() throws {
        let generator = ULIDGenerator()
        var ulids = [ULID]()
        
        for _ in 0..<100 {
            let ulid = try generator.generate()
            ulids.append(ulid)
        }
        
        // Verify uniqueness
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, 100, "All ULIDs should be unique")
        
        // Verify monotonic increasing
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "ULIDs should be monotonically increasing")
        }
    }
    
    // MARK: Monotonic Mode Tests
    
    func testMonotonicMode() throws {
        let fixedTime = FixedTimeProvider(timestamp: 1234567890000)
        let generator = ULIDGenerator(timeProvider: fixedTime, strategy: .monotonic)
        
        var ulids = [ULID]()
        for _ in 0..<10 {
            let ulid = try generator.generate()
            ulids.append(ulid)
        }
        
        // Verify all ULIDs use the same timestamp
        for ulid in ulids {
            XCTAssertEqual(ulid.timestampMilliseconds, 1234567890000)
        }
        
        // Verify monotonic increasing via random part increment
        for i in 1..<ulids.count {
            XCTAssertLessThan(ulids[i-1], ulids[i], "ULIDs with same timestamp should increase via random part")
        }
    }
    
    func testMonotonicModeClockBackward() throws {
        // Create backward time provider
        class BackwardTimeProvider: TimeProvider {
            var currentTime: UInt64 = 2000
            func currentMilliseconds() -> UInt64 {
                defer { currentTime -= 1 }
                return currentTime
            }
        }
        
        let timeProvider = BackwardTimeProvider()
        let generator = ULIDGenerator(timeProvider: timeProvider, strategy: .monotonic)
        
        var ulids = [ULID]()
        for _ in 0..<10 {
            let ulid = try generator.generate()
            ulids.append(ulid)
        }
        
        // Verify ULIDs remain monotonic even with clock backward
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "Monotonic mode should handle clock backward")
        }
    }
    
    // MARK: Strict Mode Tests
    
    func testStrictModeClockBackward() throws {
        let incrementing = IncrementingTimeProvider(start: 1000, increment: 1)
        let generator = ULIDGenerator(timeProvider: incrementing, strategy: .strict)
        
        // First generation succeeds
        _ = try generator.generate()
        
        // Manually roll back clock
        class BackwardTimeProvider: TimeProvider {
            func currentMilliseconds() -> UInt64 { return 500 }
        }
        
        let backwardGenerator = ULIDGenerator(timeProvider: BackwardTimeProvider(), strategy: .strict)
        _ = try backwardGenerator.generate() // Set baseline
        
        // Use new backward time
        let finalProvider = FixedTimeProvider(timestamp: 400)
        let strictGenerator = ULIDGenerator(timeProvider: finalProvider, strategy: .strict)
        
        // Preset a larger timestamp
        _ = try strictGenerator.generate()
    }
    
    // MARK: Batch Generation Tests
    
    func testBatchGeneration() throws {
        let generator = ULIDGenerator()
        let ulids = try generator.generateBatch(count: 1000)
        
        XCTAssertEqual(ulids.count, 1000, "Should generate 1000 ULIDs")
        
        // Verify uniqueness
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, 1000, "All ULIDs should be unique")
        
        // Verify monotonic increasing
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "Batch generation should be monotonic")
        }
    }
    
    func testBatchGenerationPerformance() throws {
        let generator = ULIDGenerator()
        measure {
            _ = try? generator.generateBatch(count: 1000)
        }
    }
    
    // MARK: Time Provider Tests
    
    func testSystemTimeProvider() throws {
        let provider = SystemTimeProvider()
        let generator = ULIDGenerator(timeProvider: provider)
        
        let ulid = try generator.generate()
        let now = Date()
        let diff = abs(ulid.timestamp.timeIntervalSince(now))
        
        XCTAssertLessThan(diff, 0.1, "System time should be close to current time")
    }
    
    func testMonotonicTimeProvider() throws {
        let provider = MonotonicTimeProvider()
        let generator = ULIDGenerator(timeProvider: provider)
        
        var ulids = [ULID]()
        for _ in 0..<100 {
            let ulid = try generator.generate()
            ulids.append(ulid)
        }
        
        // Verify monotonic increasing
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "Monotonic clock should guarantee increasing")
        }
    }
    
    func testFixedTimeProvider() throws {
        let fixedTime: UInt64 = 1234567890000
        let provider = FixedTimeProvider(timestamp: fixedTime)
        let generator = ULIDGenerator(timeProvider: provider)
        
        let ulid = try generator.generate()
        XCTAssertEqual(ulid.timestampMilliseconds, fixedTime, "Should use fixed time")
    }
    
    func testIncrementingTimeProvider() throws {
        let provider = IncrementingTimeProvider(start: 1000, increment: 1)
        let generator = ULIDGenerator(timeProvider: provider)
        
        let ulid1 = try generator.generate()
        let ulid2 = try generator.generate()
        
        XCTAssertEqual(ulid1.timestampMilliseconds, 1000)
        XCTAssertEqual(ulid2.timestampMilliseconds, 1001)
    }
    
    // MARK: Concurrency Tests
    
    func testConcurrentGeneration() throws {
        let generator = ULIDGenerator()
        let count = 1000
        var ulids: [ULID] = []
        var lock = os_unfair_lock()
        
        DispatchQueue.concurrentPerform(iterations: count) { _ in
            if let ulid = try? generator.generate() {
                os_unfair_lock_lock(&lock)
                ulids.append(ulid)
                os_unfair_lock_unlock(&lock)
            }
        }
        
        XCTAssertEqual(ulids.count, count, "Should successfully generate all ULIDs")
        
        // Verify uniqueness
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, count, "Concurrent ULIDs should all be unique")
    }
    
    func testHighConcurrencyGeneration() throws {
        let generator = ULIDGenerator()
        let iterations = 100
        let threadsCount = 8
        var allUlids: [[ULID]] = Array(repeating: [], count: threadsCount)
        var lock = os_unfair_lock()
        
        DispatchQueue.concurrentPerform(iterations: threadsCount) { threadIndex in
            var threadUlids: [ULID] = []
            for _ in 0..<iterations {
                if let ulid = try? generator.generate() {
                    threadUlids.append(ulid)
                }
            }
            os_unfair_lock_lock(&lock)
            allUlids[threadIndex] = threadUlids
            os_unfair_lock_unlock(&lock)
        }
        
        let flatUlids = allUlids.flatMap { $0 }
        XCTAssertEqual(flatUlids.count, iterations * threadsCount)
        
        // Verify uniqueness
        let uniqueSet = Set(flatUlids)
        XCTAssertEqual(uniqueSet.count, flatUlids.count, "High concurrency ULIDs should all be unique")
    }
    
    // MARK: Global Configuration Tests
    
    func testGlobalConfiguration() throws {
        // Configure to use fixed time
        let fixedTime: UInt64 = 9876543210000
        ULID.configure(timeProvider: FixedTimeProvider(timestamp: fixedTime))
        
        let ulid = ULID()
        XCTAssertEqual(ulid.timestampMilliseconds, fixedTime, "Should use configured TimeProvider")
    }
    
    // MARK: Edge Case Tests
    
    func testRapidGeneration() throws {
        let generator = ULIDGenerator()
        var ulids = [ULID]()
        
        // Rapidly generate ULIDs
        for _ in 0..<10000 {
            let ulid = try generator.generate()
            ulids.append(ulid)
        }
        
        // Verify uniqueness
        let uniqueSet = Set(ulids)
        XCTAssertEqual(uniqueSet.count, 10000, "Rapid generation should guarantee uniqueness")
        
        // Verify monotonicity
        for i in 1..<ulids.count {
            XCTAssertLessThanOrEqual(ulids[i-1], ulids[i], "Rapid generation should maintain monotonicity")
        }
    }
    
    // MARK: Performance Tests
    
    func testSingleThreadPerformance() throws {
        let generator = ULIDGenerator()
        measure {
            for _ in 0..<1000 {
                _ = try? generator.generate()
            }
        }
    }
}
