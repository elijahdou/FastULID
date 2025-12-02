# Lock Performance Comparison

This benchmark compares different lock implementations used in FastULID's `ULIDGenerator`.

## Lock Implementations Tested

### 1. os_unfair_lock (C API)
- Direct C function calls
- Maximum performance
- Used in FastULID for iOS 15
- Requires manual memory management

### 2. OSAllocatedUnfairLock (Swift API)
- Swift wrapper with automatic memory management
- Closure-based API for safety
- Used in FastULID for iOS 16+/macOS 13+
- Minimal overhead (~1-2ns per operation)

### 3. NSLock (Reference Baseline)
- Traditional Objective-C lock
- Higher overhead
- Included for comparison

## Why This Matters

FastULID's `ULIDGenerator` uses platform-specific lock strategies:

- **iOS 16+/macOS 13+**: Uses `OSAllocatedUnfairLock`
  - Memory-safe Swift API
  - Automatic cleanup
  - Minimal performance overhead

- **iOS 15**: Uses `os_unfair_lock`
  - Direct C API for maximum performance
  - Manual memory management
  - Best performance on older platforms

## Running the Benchmark

```bash
# From project root
swift Benchmarks/LockComparison/main.swift

# Or with optimizations (recommended)
swift -O Benchmarks/LockComparison/main.swift
```

## Typical Results

On Apple Silicon (M1/M2):

| Lock Type | Per Operation | Throughput | Overhead |
|-----------|--------------|------------|----------|
| os_unfair_lock | ~80 ns | ~12M ops/s | Baseline |
| OSAllocatedUnfairLock | ~82 ns | ~12M ops/s | +1-2 ns |
| NSLock | ~100 ns | ~10M ops/s | +20 ns |

## Key Findings

1. **OSAllocatedUnfairLock overhead is minimal** (~1-2ns)
   - Worth it for memory safety and automatic cleanup
   - Preferred on modern platforms

2. **os_unfair_lock is fastest** but requires careful memory management
   - Used on iOS 15 where OSAllocatedUnfairLock is unavailable
   - Direct C API has no abstraction overhead

3. **NSLock is significantly slower** (~20ns overhead)
   - Not suitable for high-performance scenarios
   - FastULID never uses NSLock

## Implementation in FastULID

See `Sources/FastULID/ULIDGeneratorLock.swift` for the actual implementation:

```swift
@available(iOS 16.0, macOS 13.0, *)
final class SafeULIDGeneratorLock {
    private let lock: OSAllocatedUnfairLock<State>
    // ...
}

final class UnsafeULIDGeneratorLock {
    private let lock: os_unfair_lock_t
    // ...
}
```

The generator automatically selects the appropriate lock based on platform availability.

