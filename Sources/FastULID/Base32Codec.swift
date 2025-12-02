//
// Base32Codec.swift
// ULID
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// High-performance Base32 encoder/decoder
// Uses Crockford's Base32 encoding scheme
//
// Performance optimizations:
// - Uses static lookup tables, reduces computation
// - Uses bitwise operations instead of division and modulo
// - Inlines all critical functions
// - Optimized for ULID-specific length (26 char)
//

import Foundation

/// Base32 encoder/decoder
///
/// Uses Crockford's Base32 encoding scheme:
/// - Character set: 0-9 A-Z (excluding I, L, O, U)
/// - Case-insensitive
/// - Supports i, l, o substitution to 1, 1, 0
///
/// Performance optimizations:
/// - Encoding/decoding tables use static constants, compile-time optimization
/// - Specialized for ULID's 26-character length, loop unrolling
/// - Uses SIMD instructions for batch processing (to be implemented)
@usableFromInline
internal enum Base32Codec {
    
    // MARK: - Encoding Table
    
    /// Crockford's Base32 encoding table
    ///
    /// 32 char: 0123456789ABCDEFGHJKMNPQRSTVWXYZ
    /// Excludes confusing letters: I(1), L(1), O(0), U
    @usableFromInline
    internal static let encodingTable: [UInt8] = [
        // 0    1    2    3    4    5    6    7    8    9
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, // 0-9
        // A    B    C    D    E    F    G    H    J    K
        0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x4A, 0x4B, // 10-19
        // M    N    P    Q    R    S    T    V    W    X
        0x4D, 0x4E, 0x50, 0x51, 0x52, 0x53, 0x54, 0x56, 0x57, 0x58, // 20-29
        // Y    Z
        0x59, 0x5A  // 30-31
    ]
    
    // MARK: - Decoding Table
    
    /// Crockford's Base32 decoding table (256 byte, covers all ASCII char)
    ///
    /// Performance optimizations:
    /// - Uses 256-byte table instead of HashMap, O(1) lookup
    /// - 0xFF indicates invalid character
    /// - Supports upper/lowercase letters
    /// - Supports i/I -> 1, l/L -> 1, o/O -> 0 substitution
    @usableFromInline
    internal static let decodingTable: [UInt8] = [
        // Control char 0x00-0x1F (invalid)
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // 0x20-0x2F (space and symbols, except digits)
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // 0x30-0x3F (digits 0-9 and some symbols)
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // 0x40-0x4F (@ and uppercase A-O)
        // @, A,    B,    C,    D,    E,    F,    G,    H,    I,    J,    K,    L,    M,    N,    O
        0xFF, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00,
        
        // 0x50-0x5F (uppercase P-Z and some symbols)
        // P,    Q,    R,    S,    T,    U,    V,    W,    X,    Y,    Z,    [,    \,    ],    ^,    _
        0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // 0x60-0x6F (` and lowercase a-o)
        // `,    a,    b,    c,    d,    e,    f,    g,    h,    i,    j,    k,    l,    m,    n,    o
        0xFF, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00,
        
        // 0x70-0x7F (lowercase p-z and some symbols)
        // p,    q,    r,    s,    t,    u,    v,    w,    x,    y,    z,    {,    |,    },    ~,    DEL
        0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        
        // Extended ASCII 0x80-0xFF (all invalid)
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    ]
    
    // MARK: - ULID-Specific Encoding (26 char)
    
    /// Encode ULID to 26-character Base32 string
    ///
    /// - Parameters:
    ///   - high: ULID high 64 bits
    ///   - low: ULID low 64 bits
    ///
    /// - Returns: 26-character Base32 string
    ///
    /// Performance optimizations:
    /// - Specialized for ULID's 128-bit length
    /// - Loop unrolling, reduced branches
    /// - Uses UnsafeMutablePointer for direct writes, avoiding array operations
    /// - Pre-allocates fixed-size buffer
    ///
    /// Encoding layout (standard ULID specification):
    /// - 128 bits encoded as 130 bits (2-bit padding + 128-bit data)
    /// - Character 0: only 3 bits valid (max value 7)
    /// - Characters 1-25: 5 bits each
    @inline(__always)
    @usableFromInline
    internal static func encodeULID(high: UInt64, low: UInt64) -> String {
        return String(unsafeUninitializedCapacity: 26) { buffer in
            // Timestamp part (characters 0-9, 48 bits from high[63:16])
            // Character 0: only 3 bits valid (bits 127-125 of 130-bit representation)
            buffer[0]  = encodingTable[Int((high >> 61) & 0x07)]  // 3 bits only, max 7
            buffer[1]  = encodingTable[Int((high >> 56) & 0x1F)]
            buffer[2]  = encodingTable[Int((high >> 51) & 0x1F)]
            buffer[3]  = encodingTable[Int((high >> 46) & 0x1F)]
            buffer[4]  = encodingTable[Int((high >> 41) & 0x1F)]
            buffer[5]  = encodingTable[Int((high >> 36) & 0x1F)]
            buffer[6]  = encodingTable[Int((high >> 31) & 0x1F)]
            buffer[7]  = encodingTable[Int((high >> 26) & 0x1F)]
            buffer[8]  = encodingTable[Int((high >> 21) & 0x1F)]
            buffer[9]  = encodingTable[Int((high >> 16) & 0x1F)]
            
            // Random part (characters 10-25, 80 bits: high[15:0] + low[63:0])
            buffer[10] = encodingTable[Int((high >> 11) & 0x1F)]
            buffer[11] = encodingTable[Int((high >> 6)  & 0x1F)]
            buffer[12] = encodingTable[Int((high >> 1)  & 0x1F)]
            
            // Character 13: 1 bit from high + 4 bits from low
            buffer[13] = encodingTable[Int(((high & 0x01) << 4) | ((low >> 60) & 0x0F))]
            
            // Remaining low 64 bits
            buffer[14] = encodingTable[Int((low >> 55) & 0x1F)]
            buffer[15] = encodingTable[Int((low >> 50) & 0x1F)]
            buffer[16] = encodingTable[Int((low >> 45) & 0x1F)]
            buffer[17] = encodingTable[Int((low >> 40) & 0x1F)]
            buffer[18] = encodingTable[Int((low >> 35) & 0x1F)]
            buffer[19] = encodingTable[Int((low >> 30) & 0x1F)]
            buffer[20] = encodingTable[Int((low >> 25) & 0x1F)]
            buffer[21] = encodingTable[Int((low >> 20) & 0x1F)]
            buffer[22] = encodingTable[Int((low >> 15) & 0x1F)]
            buffer[23] = encodingTable[Int((low >> 10) & 0x1F)]
            buffer[24] = encodingTable[Int((low >> 5)  & 0x1F)]
            buffer[25] = encodingTable[Int(low & 0x1F)]
            
            return 26
        }
    }
    
    // MARK: - ULID-Specific Decoding (26 char)
    
    /// Decode 26-character Base32 string to ULID
    ///
    /// - Parameter string: 26-character Base32 string
    ///
    /// - Returns: Decoded (high, low) tuple, nil if decoding fails
    ///
    /// Performance optimizations:
    /// - Fast path: ASCII char use direct table lookup
    /// - Early validation of character validity, avoiding wasted computation
    /// - Bit operations unrolled, reduced loops
    ///
    /// Decoding layout (standard ULID specification):
    /// - Character 0: only 3 bits valid (must be <= 7)
    /// - Characters 1-25: 5 bits each
    @inline(__always)
    @usableFromInline
    internal static func decodeULIDString(_ string: String) -> (high: UInt64, low: UInt64)? {
        // Must be 26 char
        guard string.count == 26 else { return nil }
        
        // Helper function to process buffer directly
        func process(_ ptr: UnsafeBufferPointer<UInt8>) -> (UInt64, UInt64)? {
            // Helper to decode a single byte to UInt64 (0-31), returns nil if invalid
            @inline(__always)
            func v(_ i: Int) -> UInt64? {
                let val = decodingTable[Int(ptr[i])]
                if val == 0xFF { return nil }
                return UInt64(val)
            }
            
            // Decode all 26 characters
            // Unrolling 26 calls avoids array allocation and loop overhead
            guard let v0 = v(0), let v1 = v(1), let v2 = v(2), let v3 = v(3),
                  let v4 = v(4), let v5 = v(5), let v6 = v(6), let v7 = v(7),
                  let v8 = v(8), let v9 = v(9), let v10 = v(10), let v11 = v(11),
                  let v12 = v(12), let v13 = v(13), let v14 = v(14), let v15 = v(15),
                  let v16 = v(16), let v17 = v(17), let v18 = v(18), let v19 = v(19),
                  let v20 = v(20), let v21 = v(21), let v22 = v(22), let v23 = v(23),
                  let v24 = v(24), let v25 = v(25) else { return nil }
            
            // Validate first character (must be <= 7, as only 3 bits are valid)
            guard v0 <= 7 else { return nil }
            
            // Standard ULID decoding (130-bit representation with 2-bit padding)
            // High 64 bits: v0(3 bits) + v1-v12(60 bits) + v13 high bit(1 bit)
            var high: UInt64 = (v0 << 61) | (v1 << 56) | (v2 << 51) | (v3 << 46)
            high |= (v4 << 41) | (v5 << 36) | (v6 << 31) | (v7 << 26)
            high |= (v8 << 21) | (v9 << 16) | (v10 << 11) | (v11 << 6)
            high |= (v12 << 1) | (v13 >> 4)
            
            // Low 64 bits: v13 low 4 bits + v14-v25(60 bits)
            var low: UInt64 = ((v13 & 0x0F) << 60) | (v14 << 55) | (v15 << 50) | (v16 << 45)
            low |= (v17 << 40) | (v18 << 35) | (v19 << 30) | (v20 << 25)
            low |= (v21 << 20) | (v22 << 15) | (v23 << 10) | (v24 << 5) | v25
                
            return (high, low)
        }
        
        // Fast path: Access contiguous UTF-8 storage directly (Zero-Copy)
        if let result = string.utf8.withContiguousStorageIfAvailable({ process($0) }) {
            return result
        }
        
        // Slow path: Convert to Array (Allocation involved)
        // Needed for non-contiguous strings (e.g. some bridged NSStrings)
        let array = Array(string.utf8)
        return array.withUnsafeBufferPointer { process($0) }
    }
}

// MARK: - Generic Base32 Encoding/Decoding (Compatible with Original API)

extension Data {
    
    /// Decode from Base32 string (generic version)
    ///
    /// - Parameter base32String: Base32 encoded string
    ///
    /// - Returns: Decoded binary data, nil if decoding fails
    ///
    /// Supported formats:
    /// - Standard Base32 (with padding)
    /// - Base32 without padding
    ///
    /// This method maintains compatibility with original implementation
    init?(base32Encoded base32String: String) {
        // Remove trailing padding char (=)
        var cleanString = base32String
        if let lastNonPadding = cleanString.lastIndex(where: { $0 != "=" }) {
            cleanString = String(cleanString[...lastNonPadding])
        }
        
        let utf8 = Array(cleanString.utf8)
        
        // Validate length (must be valid Base32 length)
        let validLengths = [0, 2, 4, 5, 7] // Per 8 char as a group, allowed remainders
        guard validLengths.contains(utf8.count % 8) else { return nil }
        
        // Calculate output length
        let outputLength = utf8.count * 5 / 8
        var bytes = [UInt8](repeating: 0, count: outputLength)
        
        var inputIndex = 0
        var outputIndex = 0
        
        while inputIndex < utf8.count {
            // Process up to 8 char (40 bits) each time
            let chunkSize = Swift.min(8, utf8.count - inputIndex)
            var chunk = [UInt8](repeating: 0, count: 8)
            
            // Decode current block
            for i in 0..<chunkSize {
                let byte = utf8[inputIndex + i]
                guard byte < 128 else { return nil }
                
                let value = Base32Codec.decodingTable[Int(byte)]
                guard value != 0xFF else { return nil }
                
                chunk[i] = value
            }
            
            // Rebuild bytes based on block size
            switch chunkSize {
            case 8:
                bytes[outputIndex + 4] = (chunk[6] << 5) | chunk[7]
                fallthrough
            case 7:
                bytes[outputIndex + 3] = (chunk[4] << 7) | (chunk[5] << 2) | (chunk[6] >> 3)
                fallthrough
            case 5:
                bytes[outputIndex + 2] = (chunk[3] << 4) | (chunk[4] >> 1)
                fallthrough
            case 4:
                bytes[outputIndex + 1] = (chunk[1] << 6) | (chunk[2] << 1) | (chunk[3] >> 4)
                fallthrough
            case 2:
                bytes[outputIndex + 0] = (chunk[0] << 3) | (chunk[1] >> 2)
            default:
                break
            }
            
            inputIndex += 8
            outputIndex += 5
        }
        
        self.init(bytes)
    }
    
    /// Encode to Base32 string (generic version)
    ///
    /// - Parameters:
    ///   - padding: Whether to add padding (=)
    ///   - table: Encoding table (defaults to Crockford's Base32)
    ///
    /// - Returns: Base32 encoded string
    ///
    /// This method maintains compatibility with original implementation
    func base32EncodedString(padding: Bool = true) -> String {
        return self.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String in
            let src = ptr.bindMemory(to: UInt8.self)
            let srcCount = src.count
            
            // Calculate output length
            let outputLength: Int
            if padding {
                outputLength = (srcCount + 4) / 5 * 8
            } else {
                outputLength = (srcCount * 8 + 4) / 5
            }
            
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: outputLength + 1)
            defer { buffer.deallocate() }
            
            var srcIndex = 0
            var dstIndex = 0
            
            while srcIndex < srcCount {
                let remaining = srcCount - srcIndex
                var chunk = [UInt8](repeating: 0, count: 8)
                
                // Extract bits from input and encode
                switch remaining {
                case let x where x >= 5:
                    chunk[7] = src[srcIndex + 4] & 0x1F
                    chunk[6] = src[srcIndex + 4] >> 5
                    fallthrough
                case 4:
                    chunk[6] |= (src[srcIndex + 3] << 3) & 0x1F
                    chunk[5] = (src[srcIndex + 3] >> 2) & 0x1F
                    chunk[4] = src[srcIndex + 3] >> 7
                    fallthrough
                case 3:
                    chunk[4] |= (src[srcIndex + 2] << 1) & 0x1F
                    chunk[3] = (src[srcIndex + 2] >> 4) & 0x1F
                    fallthrough
                case 2:
                    chunk[3] |= (src[srcIndex + 1] << 4) & 0x1F
                    chunk[2] = (src[srcIndex + 1] >> 1) & 0x1F
                    chunk[1] = (src[srcIndex + 1] >> 6) & 0x1F
                    fallthrough
                case 1:
                    chunk[1] |= (src[srcIndex + 0] << 2) & 0x1F
                    chunk[0] = (src[srcIndex + 0] >> 3) & 0x1F
                default:
                    break
                }
                
                // Encode char
                let charCount = Swift.min(8, outputLength - dstIndex)
                for i in 0..<charCount {
                    buffer[dstIndex + i] = Base32Codec.encodingTable[Int(chunk[i])]
                }
                
                // Add padding
                if remaining < 5 && padding {
                    let paddingStart: Int
                    switch remaining {
                    case 1: paddingStart = 2
                    case 2: paddingStart = 4
                    case 3: paddingStart = 5
                    case 4: paddingStart = 7
                    default: paddingStart = 8
                    }
                    
                    for i in paddingStart..<8 where dstIndex + i < outputLength {
                        buffer[dstIndex + i] = 0x3D // '='
                    }
                    dstIndex += 8
                    break
                }
                
                srcIndex += 5
                dstIndex += 8
            }
            
            buffer[outputLength] = 0
            return String(cString: buffer)
        }
    }
}

