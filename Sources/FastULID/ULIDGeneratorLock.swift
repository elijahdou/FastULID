//
// ULIDGeneratorLock.swift
// ULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//

import Foundation

#if canImport(os)
import os
#endif

// MARK: - Lock Abstraction

/// High-performance lock for ULID generator state
/// - iOS 15+: Uses os_unfair_lock (excellent performance)
/// - iOS 16+: Uses OSAllocatedUnfairLock is better than os_unfair_lock
///
/// Implementation details:
/// - Uses `os_unfair_lock` directly (C API)
/// - Provides a safe Swift wrapper
/// - Guaranteed critical section safety
/// - @unchecked Sendable because we manage thread safety internally via the lock
@usableFromInline
internal final class ULIDLock<State>: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The underlying C lock
    /// Needs to be a pointer because os_unfair_lock is a struct and cannot be moved
    private let lock: os_unfair_lock_t
    
    /// The protected state
    /// Access is only allowed via withLock closure
    private var state: State
    
    // MARK: - Initialization
    
    /// Initialize with initial state
    /// - Parameter initialState: The initial state value
    @inline(__always)
    init(initialState: State) {
        self.state = initialState
        self.lock = .allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Clean up unmanaged memory
        lock.deinitialize(count: 1)
        lock.deallocate()
    }
    
    // MARK: - Locking
    
    /// Execute block with exclusive access to state
    ///
    /// Performance:
    /// - Inlined (@inline(__always)) to remove function call overhead
    /// - Direct C function call to os_unfair_lock_lock
    /// - Zero allocations
    ///
    /// - Parameter block: Closure to execute with state access
    /// - Returns: Result of the closure
    @inline(__always)
    @usableFromInline
    func withLock<T>(_ block: (inout State) throws -> T) rethrows -> T {
        os_unfair_lock_lock(lock)
        defer {
            os_unfair_lock_unlock(lock)
        }
        
        return try block(&state)
    }
}
