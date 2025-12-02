//
// ULID.swift
// ULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// High-performance ULID implementation
// Universally Unique Lexicographically Sortable Identifier
//
// Memory layout optimized version: Uses two UInt64 for improved comparison and operation performance
//

import Foundation

/// ULID type alias for compatibility with original API
public typealias ulid_t = uuid_t

/// Universally Unique Lexicographically Sortable Identifier
///
/// ULID is a 128-bit identifier consisting of:
/// - 48-bit timestamp (millisecond precision)
/// - 80-bit random value
///
/// Memory layout:
/// ```
/// 0                   1                   2                   3
/// 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                    Timestamp (high 32 bits)                    |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |  Timestamp(low 16) |        Random (high 16 bits)             |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                    Random (mid 32 bits)                        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// |                    Random (low 32 bits)                        |
/// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
/// ```
///
/// Performance optimizations:
/// - Uses two UInt64 storage, ~3-5x faster than 16-byte tuple
/// - Comparison operations use native UInt64 comparison, leveraging CPU pipeline
/// - All critical path methods marked as @inline(__always)
@frozen
public struct ULID: Hashable, Equatable, Comparable, CustomStringConvertible, Sendable {
    
    // MARK: - Internal Storage
    
    /// Named tuple storage for high and low 64-bit parts
    /// - high: Contains full 48-bit timestamp and 16-bit random [timestamp(48)] [random(16)]
    /// - low: Contains remaining 64-bit random [random(64)]
    @usableFromInline
    internal var bytes: (high: UInt64, low: UInt64)
    
    // MARK: - Initialization Methods
    
    /// Create ULID from two UInt64 values (internal use)
    ///
    /// - Parameters:
    ///   - high: High 64 bits (timestamp 48 bits + random 16 bits)
    ///   - low: Low 64 bits (random 64 bits)
    @inline(__always)
    @usableFromInline
    internal init(high: UInt64, low: UInt64) {
        self.bytes = (high: high, low: low)
    }
    
    /// Create ULID from ulid_t (16-byte tuple)
    ///
    /// - Parameter ulid: 16-byte ULID data
    ///
    /// Performance optimization: Uses withUnsafeBytes for zero-copy conversion
    @inline(__always)
    public init(ulid: ulid_t) {
        var temp = ulid
        // Zero-copy conversion, read UInt64 directly from memory
        var tmpHigh: UInt64 = 0
        var tmpLow: UInt64 = 0
        withUnsafeBytes(of: &temp) { ptr in
            let u64Ptr = ptr.bindMemory(to: UInt64.self)
            // Note: Consider byte order, using big-endian for cross-platform consistency
            tmpHigh = UInt64(bigEndian: u64Ptr[0])
            tmpLow = UInt64(bigEndian: u64Ptr[1])
        }
        self.bytes = (high: tmpHigh, low: tmpLow)
    }
    
    /// Create ULID from Data
    ///
    /// - Parameter data: 16-byte binary data
    /// - Returns: nil if data length is not 16 bytes
    ///
    /// Performance optimization: Uses withUnsafeBytes to avoid array allocation
    @inline(__always)
    public init?(ulidData data: Data) {
        guard data.count == 16 else { return nil }
        
        let h = data.withUnsafeBytes { ptr in
            let u64Ptr = ptr.bindMemory(to: UInt64.self)
            return UInt64(bigEndian: u64Ptr[0])
        }
        
        let l = data.dropFirst(8).withUnsafeBytes { ptr in
            let u64Ptr = ptr.bindMemory(to: UInt64.self)
            return UInt64(bigEndian: u64Ptr[0])
        }
        self.bytes = (high: h, low: l)
    }
    
    /// Create ULID from Base32 encoded string
    ///
    /// - Parameter string: 26-character Base32 encoded string
    /// - Returns: nil if string format is invalid
    ///
    /// ULID string format: 26 characters using Crockford's Base32 encoding
    /// - First 10 characters: Timestamp part (48 bits)
    /// - Last 16 characters: Random part (80 bits)
    @inline(__always)
    public init?(ulidString string: String) {
        // Quick validation: length must be 26
        guard string.utf8.count == 26 else { return nil }
        
        // Use optimized Base32 decoder
        guard let decoded = Base32Codec.decodeULIDString(string) else {
            return nil
        }
        
        self.bytes = (high: decoded.high, low: decoded.low)
    }
    
    /// Create ULID with specified timestamp and random data
    ///
    /// - Parameters:
    ///   - timestamp: Timestamp (Date object)
    ///   - data: At least 10 bytes of random data (only first 10 bytes used)
    /// - Returns: nil if data is less than 10 bytes
    ///
    /// Note: This method uses provided random data directly, doesn't guarantee uniqueness
    public init?(timestamp: Date = Date(), randomPartData data: Data) {
        let requiredBytes = 10
        guard data.count >= requiredBytes else { return nil }
        
        // Extract timestamp (milliseconds)
        let milliseconds = UInt64(timestamp.timeIntervalSince1970 * 1000.0)
        
        // Build high 64 bits: timestamp 48 bits + random high 16 bits
        let randomHigh16 = data.withUnsafeBytes { ptr in
            UInt16(bigEndian: ptr.loadUnaligned(as: UInt16.self))
        }
        let h = (milliseconds << 16) | UInt64(randomHigh16)
        
        // Build low 64 bits: random low 64 bits
        let l = data.dropFirst(2).prefix(8).withUnsafeBytes { ptr in
            UInt64(bigEndian: ptr.loadUnaligned(as: UInt64.self))
        }
        self.bytes = (high: h, low: l)
    }
    
    /// Create ULID with specified timestamp and random generator
    ///
    /// - Parameters:
    ///   - timestamp: Timestamp (Date object)
    ///   - generator: Random number generator
    ///
    /// Performance optimization: Generates required random numbers in one go, avoiding multiple RNG calls
    @inline(__always)
    public init<T: RandomNumberGenerator>(timestamp: Date, generator: inout T) {
        // Extract timestamp (milliseconds)
        let milliseconds = UInt64(timestamp.timeIntervalSince1970 * 1000.0)
        
        // Generate 80-bit random (using two random() calls)
        let random16 = UInt16.random(in: .min ... .max, using: &generator)
        let random64 = UInt64.random(in: .min ... .max, using: &generator)
        
        // Assemble high and low 64 bits
        self.bytes = (high: (milliseconds << 16) | UInt64(random16), low: random64)
    }
    
    /// Create ULID with global configuration
    ///
    /// Uses the global ULID.defaultGenerator
    ///
    /// Note:
    /// - Affected by ULID.configure()
    /// - If the global generator fails (e.g., strict mode clock rollback), falls back to system time + random
    @inline(__always)
    public init() {
        // Try to use global generator
        if let ulid = try? ULID.defaultGenerator.generate() {
            self.bytes = ulid.bytes
        } else {
            // Fallback: Use system time + random (same as old implementation)
            // This ensures we always return a valid ULID even if strict mode fails
            
            // Extract timestamp (milliseconds)
            let milliseconds = UInt64(Date().timeIntervalSince1970 * 1000.0)
            
            // Use arc4random_buf to generate random numbers (C function, best performance)
            var randomBytes = (UInt16(0), UInt64(0))
            withUnsafeMutableBytes(of: &randomBytes) { ptr in
                arc4random_buf(ptr.baseAddress!, 10)
            }
            
            // Assemble high and low 64 bits
            self.bytes = (high: (milliseconds << 16) | UInt64(randomBytes.0), low: randomBytes.1)
        }
    }
    
    /// Create ULID with specified timestamp (stateless)
    ///
    /// - Parameter timestamp: The timestamp to use
    ///
    /// Note:
    /// - Not affected by global configuration
    /// - Does not guarantee monotonicity
    @inline(__always)
    public init(timestamp: Date) {
        // Extract timestamp (milliseconds)
        let milliseconds = UInt64(timestamp.timeIntervalSince1970 * 1000.0)
        
        // Use arc4random_buf to generate random numbers (C function, best performance)
        var randomBytes = (UInt16(0), UInt64(0))
        withUnsafeMutableBytes(of: &randomBytes) { ptr in
            arc4random_buf(ptr.baseAddress!, 10)
        }
        
        // Assemble high and low 64 bits
        self.bytes = (high: (milliseconds << 16) | UInt64(randomBytes.0), low: randomBytes.1)
    }

    // MARK: - Property Access
    
    /// Get ULID binary data representation (16 bytes)
    ///
    /// Returns big-endian byte sequence, ensuring cross-platform consistency
    ///
    /// Performance optimization: Uses named tuple storage directly
    @inline(__always)
    public var ulidData: Data {
        var be = (bytes.high.bigEndian, bytes.low.bigEndian)
        return withUnsafeBytes(of: &be) { Data($0) }
    }
    
    /// Get ULID string representation (26-character Base32 encoding)
    ///
    /// Uses Crockford's Base32 encoding, ensures lexical order matches chronological order
    ///
    /// Performance optimization: Uses lookup table and bitwise operations, avoiding division and modulo
    @inline(__always)
    public var ulidString: String {
        return Base32Codec.encodeULID(high: bytes.high, low: bytes.low)
    }
    
    /// Extract timestamp part from ULID
    ///
    /// ULID's first 48 bits store millisecond-precision timestamp
    ///
    /// Performance optimization: Bit shift operation, O(1) time complexity
    @inline(__always)
    public var timestamp: Date {
        // High 48 bits of high 64 bits are the timestamp
        let milliseconds = bytes.high >> 16
        return Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000.0)
    }
    
    /// Get timestamp millisecond representation
    ///
    /// Performance optimization: Direct return, no Date conversion needed
    @inline(__always)
    public var timestampMilliseconds: UInt64 {
        return bytes.high >> 16
    }
    
    /// Convert to ulid_t (16-byte tuple)
    ///
    /// Compatible with original API, used for UUID conversion
    @inline(__always)
    public var ulid: ulid_t {
        var result: ulid_t = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        
        withUnsafeMutableBytes(of: &result) { ptr in
            var highBE = bytes.high.bigEndian
            var lowBE = bytes.low.bigEndian
            
            withUnsafeBytes(of: &highBE) { highPtr in
                ptr.copyBytes(from: highPtr)
            }
            
            withUnsafeBytes(of: &lowBE) { lowPtr in
                let destPtr = UnsafeMutableRawBufferPointer(
                    start: ptr.baseAddress!.advanced(by: 8),
                    count: 8
                )
                destPtr.copyBytes(from: lowPtr)
            }
        }
        
        return result
    }
    
    // MARK: - Hashable
    
    /// Hash function
    ///
    /// Performance optimization: Hash 16 bytes in one shot using named tuple storage
    @inline(__always)
    public func hash(into hasher: inout Hasher) {
        var b = bytes
        withUnsafeBytes(of: &b) { hasher.combine(bytes: $0) }
    }
    
    // MARK: - Equatable
    
    /// Equality comparison
    ///
    /// Performance optimization: Only compares two UInt64, ~8x faster than byte-by-byte comparison
    @inline(__always)
    public static func == (lhs: ULID, rhs: ULID) -> Bool {
        return lhs.bytes.high == rhs.bytes.high && lhs.bytes.low == rhs.bytes.low
    }
    
    // MARK: - Comparable
    
    /// Less than comparison
    ///
    /// ULID's lexical order equals chronological order
    ///
    /// Performance optimizations:
    /// - First compares high 64 bits (contains timestamp), most cases determined in one comparison
    /// - Leverages branch prediction, different timestamps are fast path
    /// - Requires at most 2 comparisons, while original implementation needs 16
    @inline(__always)
    public static func < (lhs: ULID, rhs: ULID) -> Bool {
        // Fast path: high 64 bits differ (includes timestamp)
        if lhs.bytes.high != rhs.bytes.high {
            return lhs.bytes.high < rhs.bytes.high
        }
        // Slow path: high 64 bits same, compare low 64 bits
        return lhs.bytes.low < rhs.bytes.low
    }
    
    // MARK: - CustomStringConvertible
    
    /// Description string (returns ULID string representation)
    @inline(__always)
    public var description: String {
        return ulidString
    }
}

// MARK: - Codable Extension

extension ULID: Codable {
    
    /// Decode ULID from JSON decoder
    ///
    /// Expects 26-character ULID string input
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
        guard let ulid = ULID(ulidString: string) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid ULID string：'\(string)'。ULID must be a 26-character Base32 encoded string。"
                )
            )
        }
        
        self = ulid
    }
    
    /// Encode ULID to JSON encoder
    ///
    /// Outputs as 26-character ULID string
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.ulidString)
    }
}

// MARK: - Global Configuration

extension ULID {
    
    /// Global default generator
    ///
    /// Can be configured via configure method
    internal nonisolated(unsafe) static var defaultGenerator = ULIDGenerator()
    
    /// Configure global default generator
    ///
    /// - Parameters:
    ///   - timeProvider: Time provider
    ///   - strategy: Clock drift strategy
    ///
    /// Usage example:
    /// ```swift
    /// // Configure to use NTP time
    /// ULID.configure(
    ///     timeProvider: NTPTimeProvider(),
    ///     strategy: .monotonic
    /// )
    /// ```
    ///
    /// Note:
    /// - Should be configured once at application startup
    /// - Not thread-safe, don't modify at runtime
    public static func configure(timeProvider: TimeProvider,
                                 strategy: ClockBackwardStrategy = .monotonic) {
        defaultGenerator = ULIDGenerator(timeProvider: timeProvider, strategy: strategy)
    }
}
