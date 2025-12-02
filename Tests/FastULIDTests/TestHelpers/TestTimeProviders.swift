//
// TestTimeProviders.swift
// FastULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//

import Foundation
@testable import FastULID

// MARK: - Custom Time Provider Examples

/// Fixed time provider (for testing)
///
/// Always returns a fixed timestamp
/// Used for unit testing and debugging
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

/// Incrementing time provider (for testing)
///
/// Returns incrementing timestamp on each call
/// Used for testing time series functionality
public final class IncrementingTimeProvider: TimeProvider, @unchecked Sendable {
    
    /// Internal state
    struct State {
        var currentTimestamp: UInt64
    }
    
    /// Lock for thread safety
    private let lock: ULIDLock<State>
    
    /// Increment per call (milliseconds)
    private let increment: UInt64
    
    /// Initialize incrementing time provider
    ///
    /// - Parameters:
    ///   - start: Starting timestamp (milliseconds)
    ///   - increment: Increment per call (default: 1 millisecond)
    public init(start: UInt64, increment: UInt64 = 1) {
        self.increment = increment
        self.lock = ULIDLock(initialState: State(currentTimestamp: start))
    }
    
    /// Initialize incrementing time provider
    ///
    /// - Parameters:
    ///   - startDate: Starting date
    ///   - increment: Increment per call (default: 1 millisecond)
    public init(startDate: Date, increment: UInt64 = 1) {
        let start = UInt64(startDate.timeIntervalSince1970 * 1000.0)
        self.increment = increment
        self.lock = ULIDLock(initialState: State(currentTimestamp: start))
    }
    
    /// Get timestamp and increment
    public func currentMilliseconds() -> UInt64 {
        return lock.withLock { state in
            let timestamp = state.currentTimestamp
            state.currentTimestamp += increment
            return timestamp
        }
    }
}

