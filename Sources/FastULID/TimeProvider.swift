//
// TimeProvider.swift
// ULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// Supports multiple time sources:
// - System clock (default)
// - Monotonic clock
// - NTP synchronized clock
// - Custom clock sources
//
// Used for handling clock drift issues
//

import Foundation

// MARK: - Time Provider Protocol

/// Time provider protocol
///
/// Implement this protocol to provide custom time sources
/// Use cases:
/// - NTP time synchronization
/// - Mock clock for testing
/// - Distributed system time coordination
///
/// Thread safety requirement:
/// - Implementation must be thread-safe
/// - Must support concurrent calls to currentMilliseconds()
public protocol TimeProvider: Sendable {
    
    /// Get current timestamp (milliseconds)
    ///
    /// - Returns: Unix timestamp (millisecond precision)
    ///
    /// Note:
    /// - Must return monotonically increasing timestamps (or at least non-decreasing)
    /// - Precision should be milliseconds
    func currentMilliseconds() -> UInt64
}

// MARK: - System Time Provider

/// System time provider (default implementation)
///
/// Uses system clock to get current time
///
/// Characteristics:
/// - High precision (microsecond level)
/// - Good performance (direct system call)
/// - May experience clock drift
///
/// Performance optimization:
/// - On macOS: uses clock_gettime_nsec_np for nanosecond precision
/// - Other platforms: uses Date()
public struct SystemTimeProvider: TimeProvider {
    
    /// Initialize system time provider
    public init() {}
    
    /// Get current system timestamp (milliseconds)
    ///
    /// Performance optimization:
    /// - macOS: uses clock_gettime_nsec_np (C function)
    /// - Other platforms: uses Date.timeIntervalSince1970
    @inline(__always)
    public func currentMilliseconds() -> UInt64 {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // Use high-performance clock function (nanosecond precision)
        // CLOCK_REALTIME: System real-time clock
        let nanoseconds = clock_gettime_nsec_np(CLOCK_REALTIME)
        return nanoseconds / 1_000_000
        #elseif os(Linux)
        // Linux: use clock_gettime with CLOCK_REALTIME
        var ts = timespec()
        clock_gettime(CLOCK_REALTIME, &ts)
        let milliseconds = UInt64(ts.tv_sec) * 1000 + UInt64(ts.tv_nsec) / 1_000_000
        return milliseconds
        #elseif os(Windows)
        // Windows: fallback to Date (can optimize with QueryPerformanceCounter later)
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #else
        // Other platforms use Date
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #endif
    }
}

// MARK: - Monotonic Clock Provider

/// Monotonic clock provider
///
/// Uses monotonic clock to get time
/// Monotonic clock guarantees time only moves forward
///
/// Characteristics:
/// - Not affected by system time adjustments
/// - Suitable for measuring time intervals
/// - Requires recording initial real-time clock offset
///
/// Note:
/// - First call records real-time clock and monotonic clock offset
/// - Subsequent calls use monotonic clock to calculate, ensuring no backward drift
public final class MonotonicTimeProvider: TimeProvider, @unchecked Sendable {
    
    /// Internal state protected by lock
    struct State {
        var initialRealTime: UInt64 = 0
        var initialMonotonicTime: UInt64 = 0
        var isInitialized = false
    }
    
    /// Lock for thread safety
    private let lock: ULIDLock<State>
    
    /// Initialize monotonic clock provider
    public init() {
        self.lock = ULIDLock(initialState: State())
    }
    
    /// Get current timestamp (milliseconds)
    ///
    /// Algorithm:
    /// 1. First call: Record real-time clock and monotonic clock offset
    /// 2. Subsequent calls: Use monotonic clock delta + initial real-time clock
    ///
    /// Advantages:
    /// - Guarantees time won't go backward
    /// - Good performance (monotonic clock unaffected by NTP)
    public func currentMilliseconds() -> UInt64 {
        return lock.withLock { state in
            // First call: initialize
            if !state.isInitialized {
                state.initialRealTime = SystemTimeProvider().currentMilliseconds()
                state.initialMonotonicTime = getMonotonicMilliseconds()
                state.isInitialized = true
                return state.initialRealTime
            }
            
            // Subsequent calls: use monotonic clock
            let currentMonotonic = getMonotonicMilliseconds()
            let elapsed = currentMonotonic - state.initialMonotonicTime
            return state.initialRealTime + elapsed
        }
    }
    
    /// Get monotonic clock timestamp (milliseconds)
    ///
    /// Performance optimization: Uses platform-specific high-performance API
    @inline(__always)
    private func getMonotonicMilliseconds() -> UInt64 {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // Use monotonic clock (unaffected by system time adjustments)
        let nanoseconds = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        return nanoseconds / 1_000_000
        #elseif os(Linux)
        // Linux: use clock_gettime with CLOCK_MONOTONIC
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        let milliseconds = UInt64(ts.tv_sec) * 1000 + UInt64(ts.tv_nsec) / 1_000_000
        return milliseconds
        #elseif os(Windows)
        // Windows: fallback to system time
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #else
        // Fallback for other platforms
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #endif
    }
}

// MARK: - Hybrid Time Provider

/// Hybrid time provider combining external time source with monotonic clock
///
/// This provider combines any external time source (e.g., NTP) with a monotonic clock
/// to ensure time never goes backward, while maintaining accuracy from the external source.
///
/// Key features:
/// - Uses external provider's timestamp as reference (no interference with sync logic)
/// - Guarantees monotonic time progression
/// - Thread-safe implementation
///
/// Usage example:
/// ```swift
/// // Step 1: Implement your NTP provider
/// class MyNTPProvider: TimeProvider {
///     func currentMilliseconds() -> UInt64 {
///         // Your NTP sync logic here
///         return ntpTime
///     }
/// }
///
/// // Step 2: Use with HybridTimeProvider
/// let ntpProvider = MyNTPProvider()
/// let hybridProvider = HybridTimeProvider(referenceProvider: ntpProvider)
/// let generator = ULIDGenerator(timeProvider: hybridProvider)
/// ```
public final class HybridTimeProvider: TimeProvider, @unchecked Sendable {
    
    // MARK: - Internal State
    
    /// Internal state protected by lock
    struct State {
        var initialReferenceTime: UInt64 = 0
        var initialMonotonicTime: UInt64 = 0
        var isInitialized = false
    }
    
    // MARK: - Properties
    
    /// External reference time provider (e.g., NTP provider)
    /// The provider manages its own sync logic and intervals
    private let referenceProvider: TimeProvider
    
    /// Lock for thread safety
    private let lock: ULIDLock<State>
    
    // MARK: - Initialization
    
    /// Initialize hybrid time provider with external time provider
    ///
    /// The external provider is responsible for its own synchronization logic.
    /// This class only combines it with monotonic clock for guaranteed non-backward time.
    ///
    /// - Parameter referenceProvider: External time provider (e.g., NTP provider)
    ///
    /// Example:
    /// ```swift
    /// let ntpProvider = MyNTPProvider()
    /// let hybrid = HybridTimeProvider(referenceProvider: ntpProvider)
    /// ```
    public init(referenceProvider: TimeProvider) {
        self.referenceProvider = referenceProvider
        self.lock = ULIDLock(initialState: State())
    }
    
    // MARK: - TimeProvider
    
    /// Get current timestamp (milliseconds)
    ///
    /// Algorithm:
    /// 1. First call: Get reference time from external provider
    /// 2. Record both reference time and monotonic clock baseline
    /// 3. Subsequent calls: Calculate using monotonic clock delta
    ///    Current time = Initial reference time + (Current monotonic - Initial monotonic)
    ///
    /// This ensures time never goes backward even if system clock changes,
    /// while maintaining the accuracy of the external time source.
    ///
    /// Thread safety: Protected by lock
    public func currentMilliseconds() -> UInt64 {
        return lock.withLock { state in
            // Initialize on first call
            if !state.isInitialized {
                // Get initial reference time from external provider
                state.initialReferenceTime = referenceProvider.currentMilliseconds()
                
                // Get monotonic clock baseline
                state.initialMonotonicTime = getMonotonicMilliseconds()
                
                state.isInitialized = true
                
                return state.initialReferenceTime
            }
            
            // Calculate current time using monotonic clock delta
            let currentMonotonic = getMonotonicMilliseconds()
            let elapsed = currentMonotonic - state.initialMonotonicTime
            return state.initialReferenceTime + elapsed
        }
    }
    
    // MARK: - Private Methods
    
    /// Get monotonic clock timestamp (milliseconds)
    ///
    /// Platform-specific implementation for best performance.
    /// Monotonic clock is unaffected by system time adjustments.
    @inline(__always)
    private func getMonotonicMilliseconds() -> UInt64 {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // Use CLOCK_UPTIME_RAW: monotonic time since boot
        let nanoseconds = clock_gettime_nsec_np(CLOCK_UPTIME_RAW)
        return nanoseconds / 1_000_000
        #elseif os(Linux)
        // Linux: use clock_gettime with CLOCK_MONOTONIC
        var ts = timespec()
        clock_gettime(CLOCK_MONOTONIC, &ts)
        let milliseconds = UInt64(ts.tv_sec) * 1000 + UInt64(ts.tv_nsec) / 1_000_000
        return milliseconds
        #elseif os(Windows)
        // Windows: fallback to system time
        // TODO: Could use QueryPerformanceCounter for better precision
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #else
        // Fallback for other platforms
        return UInt64(Date().timeIntervalSince1970 * 1000.0)
        #endif
    }
}

// MARK: - NTP Time Provider (Interface Reference)

/// NTP time provider interface
///
/// Users can implement this protocol with their preferred NTP library.
///
/// Recommended libraries:
/// - TrueTime.swift: https://github.com/instacart/TrueTime.swift
/// - ios-ntp: https://github.com/huynguyencong/ios-ntp
///
/// Example implementation:
/// ```swift
/// import TrueTime
///
/// class TrueTimeProvider: TimeProvider {
///     private let client = TrueTimeClient.sharedInstance
///
///     init() {
///         client.start(hostURLs: ["time.apple.com", "time.google.com"])
///     }
///
///     func currentMilliseconds() -> UInt64 {
///         if let referenceTime = client.referenceTime?.now() {
///             return UInt64(referenceTime.timeIntervalSince1970 * 1000)
///         }
///         return SystemTimeProvider().currentMilliseconds()
///     }
/// }
///
/// // Use with HybridTimeProvider
/// let ntpProvider = TrueTimeProvider()
/// let hybridProvider = HybridTimeProvider(referenceProvider: ntpProvider)
/// let generator = ULIDGenerator(timeProvider: hybridProvider)
/// ```
///
/// Note: NTP synchronization is out of scope for this library.
/// This interface allows external injection of time sources.

