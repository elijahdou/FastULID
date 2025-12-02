# Memory Comparison: FastULID vs yaslab/ULID.swift

This benchmark compares memory usage between FastULID and yaslab/ULID.swift implementations.

## Test Coverage

### 1. Static Memory Footprint
- Structure size, stride, and alignment
- Theoretical memory for storing 100,000 ULIDs

### 2. Runtime Memory Usage
- Generating 10,000 ULIDs
- Generating 100,000 ULIDs  
- Generating 1,000,000 ULIDs
- Measures actual physical memory (RSS)

### 3. String Conversion Memory Overhead
- Encoding: ULID → String (100,000 iterations)
- Decoding: String → ULID (100,000 iterations)

### 4. Batch Generation Memory Efficiency
- Compares batch mode vs individual generation
- Demonstrates memory advantages of batch API

## Running the Test

```bash
# From this directory
swift run -c release

# Or using the script
./run_memory_comparison.sh

# Or from project root
cd Benchmarks/MemoryComparison && swift run -c release
```

## Technical Details

### Memory Measurement
- Uses `mach_task_basic_info` to get accurate RSS (Resident Set Size)
- Multiple GC cycles ensure clean measurements
- `autoreleasepool` controls memory lifecycle

### Key Findings

**Advantages:**
- ✅ 28.6% less memory for 10K generations
- ✅ Zero memory allocation for string decoding
- ✅ Better cache alignment (8-byte vs 1-byte)
- ✅ Predictable memory usage in batch mode

**Structure:**
- Both implementations use 16 bytes per ULID
- FastULID: 2x UInt64 with 8-byte alignment
- yaslab: byte array with 1-byte alignment

## Implementation Notes

The test uses a wrapper pattern to avoid module naming conflicts:
- `YaslabWrapper.swift` isolates yaslab's ULID module
- Main test file imports FastULID directly
- This approach prevents ambiguous type resolution

## Caveats

- Memory measurements are affected by system state
- Run multiple times and average for best accuracy
- Close other applications for more accurate results
- Large-scale tests (1M+) may show noise from GC timing

