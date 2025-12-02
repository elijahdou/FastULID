# FastULID - High Performance ULID Implementation

[中文文档](README_CN.md)

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://github.com/yaslab/ULID.swift)
[![CocoaPods](https://img.shields.io/cocoapods/v/FastULID.svg)](https://cocoapods.org/pods/FastULID)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

High-performance Swift implementation of Universally Unique Lexicographically Sortable Identifier (ULID).

The public API design is inspired by [yaslab/ULID.swift](https://github.com/yaslab/ULID.swift), designed to match Foundation's UUID API to reduce cognitive load for users. Built on this foundation with extensive performance optimizations and clock rollback handling.

## ✨ Features

### 🚀 Performance Improvements

- **~3x faster** ULID generation (vs yaslab/ULID.swift)
- **~8x faster** string encoding (vs yaslab/ULID.swift)
- **~7.5x faster** string decoding (vs yaslab/ULID.swift)
- **~5.5x faster** ULID generation (vs UUID)
- **~28x faster** batch generation (vs individual calls)
- **100% interoperable** with yaslab/ULID.swift
- **Zero-copy design**: Minimizes memory allocations


### 🎯 Core Optimizations

1. **Memory Layout**
   - Uses two `UInt64` storage (instead of 16-byte tuple)
   - Leverages 64-bit processor advantages
   - Reduces memory access and cache misses

2. **Base32 Encoding/Decoding**
   - Static lookup tables with compile-time optimization
   - Loop unrolling to reduce branches
   - Specialized for ULID's 26-character length

3. **Comparison Operations**
   - Only 2 `UInt64` comparisons (vs 16 byte comparisons)
   - Utilizes CPU branch prediction
   - Timestamp comparison as fast path

4. **Random Number Generation**
   - Uses `arc4random_buf` C function
   - Generates all required bytes at once
   - Optimized system calls for batch generation

### 🕐 Clock Drift Handling

Two strategies for handling clock drift:

#### 1. Monotonic Mode (Default)
- Uses last timestamp when clock drift detected
- Increments random part to ensure uniqueness
- Always generates valid ULIDs
- Suitable for most scenarios

#### 2. Strict Mode
- Throws error when clock drift detected
- Allows application-level handling
- Suitable for time-precision-critical scenarios

### ⏰ Configurable Time Sources

Multiple time provider options:

- **System Clock** (default): Uses system time
- **Monotonic Clock**: Guarantees time only moves forward
- **Hybrid Time Provider**: Combines external time source (e.g., NTP) with monotonic clock
- **Custom Clock**: Implement `TimeProvider` protocol

#### Using Hybrid Time Provider

Perfect for distributed systems needing both accuracy and reliability:

```swift
// Step 1: Implement your NTP provider (manages its own sync logic)
class MyNTPProvider: TimeProvider {
    func currentMilliseconds() -> UInt64 {
        // Your NTP implementation here
        return ntpTimestamp
    }
}

// Step 2: Create hybrid provider
let ntpProvider = MyNTPProvider()
let hybridProvider = HybridTimeProvider(referenceProvider: ntpProvider)
let generator = ULIDGenerator(timeProvider: hybridProvider)
```

**Why Hybrid?**
- ✅ Accurate time from external source (NTP)
- ✅ Guaranteed non-backward time (monotonic clock)
- ✅ External provider controls its own sync intervals
- ✅ No interference with external sync logic

## 📦 Installation

### Swift Package Manager

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/elijahdou/FastULID.git", from: "1.0.0")
]
```

### CocoaPods

Add to your `Podfile`:

```ruby
pod 'FastULID', '~> 1.0.0'
```

Then run:

```bash
pod install
```

## 🚀 Quick Start

### Basic Usage

```swift
import FastULID

// Generate ULID (using current time)
let ulid = ULID()

// Get ULID string
let string = ulid.ulidString
print(string) // Example: 01ARZ3NDEKTSV4RRFFQ69G5FAV

// Get ULID binary data
let data = ulid.ulidData

// Get timestamp
let timestamp = ulid.timestamp
print(timestamp) // Date object
```

### Creating from String/Data

```swift
// From string
if let ulid = ULID(ulidString: "01ARZ3NDEKTSV4RRFFQ69G5FAV") {
    print("Valid ULID")
}

// From binary data
if let ulid = ULID(ulidData: data) {
    print("Created from data")
}

// With specific timestamp
let pastDate = Date(timeIntervalSince1970: 1234567890)
let ulid = ULID(timestamp: pastDate)
```

### Using Generator (Recommended)

```swift
import FastULID

// Create generator (thread-safe)
let generator = ULIDGenerator()

// Generate ULID
let ulid = try generator.generate()

// Batch generation (performance optimized)
let ulids = try generator.generateBatch(count: 1000)
```

### Configuring Time Provider

```swift
// Use monotonic clock (prevents clock drift)
let generator = ULIDGenerator(
    timeProvider: MonotonicTimeProvider(),
    strategy: .monotonic
)

// Use fixed time (for testing)
let generator = ULIDGenerator(
    timeProvider: FixedTimeProvider(timestamp: 1234567890000)
)

// Configure global default generator (e.g. in AppDelegate)
ULID.configure(
    timeProvider: MonotonicTimeProvider(),
    strategy: .monotonic
)

// ULID() now uses the global configuration
// It will use the configured MonotonicTimeProvider
let ulid = ULID()

// Note: If strict mode is configured and clock rollback occurs,
// ULID() will fallback to system time to ensure a valid ID is always returned.
// If you need to handle strict mode errors, use ULIDGenerator directly.
```

### Clock Drift Handling

```swift
// Monotonic mode (default) - handles clock drift automatically
let generator = ULIDGenerator(strategy: .monotonic)
let ulid = try generator.generate() // Always succeeds

// Strict mode - throws error on clock drift
let strictGenerator = ULIDGenerator(strategy: .strict)
do {
    let ulid = try strictGenerator.generate()
} catch ULIDGeneratorError.clockBackward(let current, let last, let backward) {
    print("Clock drift detected: current=\(current)ms, last=\(last)ms, backward=\(backward)ms")
    // Handle error...
}
```

### JSON Serialization

```swift
import FastULID

// ULID conforms to Codable
struct User: Codable {
    let id: ULID
    let name: String
}

let user = User(id: ULID(), name: "Alice")

// Encode
let encoder = JSONEncoder()
let jsonData = try encoder.encode(user)

// Decode
let decoder = JSONDecoder()
let decodedUser = try decoder.decode(User.self, from: jsonData)
```

### UUID Conversion

```swift
// ULID to UUID
let ulid = ULID()
let uuid = UUID(uuid: ulid.ulid)
print(uuid.uuidString) // 01684626-765B-F5CE-0486-7FB7F05E443D

// UUID to ULID
let uuid = UUID()
let ulid = ULID(ulid: uuid.uuid)
print(ulid.ulidString) // 26-character Base32 encoded
```

### Sorting and Comparison

```swift
var ulids = [ULID]()
for _ in 0..<100 {
    ulids.append(ULID())
}

// ULID's lexicographic order equals time order
let sorted = ulids.sorted()

// Comparison operations
if ulid1 < ulid2 {
    print("ulid1 was generated before ulid2")
}
```

### Concurrent Generation

```swift
import FastULID

// ULIDGenerator is thread-safe
let generator = ULIDGenerator()

// Generate ULIDs from multiple threads
DispatchQueue.concurrentPerform(iterations: 10) { index in
    do {
        let ulid = try generator.generate()
        print("Thread \(index): \(ulid.ulidString)")
    } catch {
        print("Generation failed: \(error)")
    }
}

// Batch generation is more efficient for high-volume scenarios
let ulids = try generator.generateBatch(count: 10000)
print("Generated \(ulids.count) ULIDs in batch")
```

## 📊 Performance Benchmarks

**Test Platform:** Apple Silicon (arm64), 14 cores, 24GB RAM  
**Xcode Version:** 26.1.1  
**Swift Version:** 5.9+  
**Build Mode:** Release (-O)   
**Iterations:** 100,000

Run benchmark tests:

```bash
# CPU performance test
swift run -c release FastULIDBenchmark

# Complete comparison tests (performance + memory)
cd Benchmarks && ./run_all_comparisons.sh

# Or run individually:
# Memory comparison test (vs yaslab)
cd Benchmarks/MemoryComparison && ./run_memory_comparison.sh

# Performance comparison test (vs yaslab)
cd Benchmarks/YaslabComparison && swift run -c release
```

### Core Performance (Actual Test Results)

| Operation | Average Time | Throughput |
|-----------|-------------|-----------|
| ULID Generation | ~26 ns | ~38M ops/s |
| String Encoding | ~29 ns | ~34M ops/s |
| String Decoding | ~27 ns | ~37M ops/s |
| Comparison (==) | ~0 ns | ∞ |
| Hash Computation | ~12 ns | ~80M ops/s |
| Batch Generation (per ID) | ~1.7 ns | ~590M ops/s |
| Concurrent Generation (8 threads) | ~450 ns | ~2.2M ops/s |
| JSON Encoding | ~430 ns | ~2.3M ops/s |
| JSON Decoding | ~430 ns | ~2.3M ops/s |

### FastULID vs UUID

| Operation | ULID (ns) | UUID (ns) | ULID Advantage |
|-----------|-----------|-----------|----------------|
| **ID Generation** | **~27** | **~151** | **~5.6x faster** |
| **String Encoding** | **~33** | **~44** | **~1.3x faster** |
| **String Decoding** | **~25** | **~129** | **~5.2x faster** |
| **Equality Comparison** | ~0 | ~0.9 | ∞x faster |
| **Hash Computation** | ~12 | ~12 | ~1.0x (same) |
| **JSON Encoding** | **~430** | **~480** | **~1.1x faster** |
| **JSON Decoding** | **~430** | **~530** | **~1.2x faster** |
| **Batch Generation** | **~1.7** | N/A | **~28x faster** |

**Notes:**
- ✅ **Generation ~5.6x faster** - Major advantage
- ✅ **String Decoding ~5.2x faster** - Optimized zero-allocation implementation
- ✅ **String Encoding ~1.3x faster** - Faster than native UUID implementation
- ✅ **JSON Performance** - Faster serialization/deserialization than UUID
- ✅ **Batch mode ~28x faster than single generation**

### FastULID vs yaslab/ULID.swift

| Operation | FastULID (ns) | yaslab (ns) | FastULID Advantage |
|-----------|----------------|-------------|---------------------|
| **ID Generation** | **~25** | **~76** | **~3x faster** |
| **String Encoding** | **~29** | **~238** | **~8.2x faster** |
| **String Decoding** | **~28** | **~217** | **~7.8x faster** |
| **Timestamp Extraction** | **~1.4** | **~1.9** | **~1.4x faster** |
| **Data Encoding** | ~49 | ~48 | ~0.98x (same) |
| **Batch Generation** | **~1.7** | N/A | **~28x faster** |

**Notes:**
- ⚡️ **String Encoding ~8x faster** - Optimized direct bit manipulation
- ⚡️ **String Decoding ~7.8x faster** - Zero-allocation implementation
- ✅ **ID Generation ~3x faster** - Saves ~66% CPU
- ✅ **Batch mode ~28x faster than single generation** - Unique feature not available in yaslab
- ✅ **100% interoperable** - Verified identical output for String, Data, and Timestamp

### Memory Usage Comparison (FastULID vs yaslab/ULID.swift)

| Test Scenario | FastULID | yaslab | FastULID Advantage |
|--------------|----------|--------|-------------------|
| **Structure Size** | 16 bytes | 16 bytes | Same |
| **Structure Alignment** | 8 bytes | 1 byte | Better cache alignment |
| **Generate 10K** | 160 KB | 224 KB | **28.6% less** |
| **Generate 100K** | 1.56 MB | 1.53 MB | Comparable |
| **Decode 100K** | 0 MB | 1.56 MB | **100% less** |

**Memory Advantages:**
- ✅ **28.6% less memory for small-scale generation** - 10K IDs use significantly less memory
- ✅ **Zero-allocation decoding** - String decoding has no additional memory allocation
- ✅ **Better cache alignment** - 8-byte alignment optimizes CPU cache efficiency
- ✅ **Predictable batch memory** - Batch generation has stable memory usage

Run memory comparison test:
```bash
cd Benchmarks/MemoryComparison
swift run -c release MemoryComparison
# Or use the script
./run_memory_comparison.sh
```

## 🏗️ Architecture

### Module Structure

```
Sources/FastULID/
├── ULID.swift              # Core ULID struct
├── Base32Codec.swift       # High-performance Base32 encoder/decoder
├── ULIDGenerator.swift     # Thread-safe ULID generator
└── TimeProvider.swift      # Time provider protocol and implementations
```

### Memory Layout

```
ULID struct (16 bytes):
┌─────────────────────┬─────────────────────┐
│   high: UInt64      │    low: UInt64      │
├─────────────────────┴─────────────────────┤
│  Timestamp(48) | Random(16) | Random(64) │
└───────────────────────────────────────────┘
```

### Key Optimizations

1. **Compiler Hints**
   - `@inline(__always)`: Force-inline critical functions
   - `@usableFromInline`: Enable cross-module inlining
   - `@frozen`: Fix struct layout

2. **Branch Prediction**
   - Fast path optimization (timestamp differs)
   - Reduced conditional branches

3. **Cache Friendly**
   - Compact memory layout
   - Aligned lookup tables
   - Reduced pointer chasing

## 🧪 Testing

Run unit tests:

```bash
swift test
```

Test coverage > 95%, including:

- ✅ Basic functionality tests
- ✅ Encoding/decoding tests
- ✅ Sorting and comparison tests
- ✅ Clock drift handling tests
- ✅ Concurrent safety tests
- ✅ Edge case tests
- ✅ Performance tests

## 📖 ULID Specification

ULID (Universally Unique Lexicographically Sortable Identifier) is a 128-bit identifier with the following properties:

- **128-bit**: Same size as UUID
- **Lexicographically sortable**: Based on timestamp
- **Case insensitive**: Base32 encoded
- **No special characters**: URL-friendly
- **Monotonically increasing**: Guaranteed within same millisecond

### Structure

```
 01AN4Z07BY      79KA1307SR9X4MV3
|----------|    |----------------|
 Timestamp       Random
 (10 chars)      (16 chars)
 48 bits         80 bits
```

### Encoding

- Uses Crockford's Base32 encoding
- Character set: `0123456789ABCDEFGHJKMNPQRSTVWXYZ`
- Excludes confusing letters: I, L, O, U
- Case insensitive: i/I→1, l/L→1, o/O→0

For more information, see: [ULID Specification](https://github.com/ulid/spec)

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- API inspiration: [yaslab/ULID.swift](https://github.com/yaslab/ULID.swift)
- ULID specification: [ulid/spec](https://github.com/ulid/spec)
- Reference implementations:
  - [Cysharp/Ulid](https://github.com/Cysharp/Ulid) (C#)
  - [ulid-rs](https://github.com/dylanhart/ulid-rs) (Rust)

## 🔗 Related Resources

- [ULID Specification](https://github.com/ulid/spec)
- [UUID vs ULID](https://sudhir.io/uuids-ulids)

---
