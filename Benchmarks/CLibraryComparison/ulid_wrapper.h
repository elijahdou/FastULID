//
// ulid_wrapper.h
// C Library Wrapper for ULID Benchmark
//
// This header provides a simple interface to benchmark C-based ULID implementations
//

#ifndef ULID_WRAPPER_H
#define ULID_WRAPPER_H

#include <stdint.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

// ULID structure (16 bytes)
typedef struct {
    uint8_t bytes[16];
} ulid_t;

// C library benchmark functions
// These would call into an actual C ULID library

/// Generate a ULID using C implementation
/// @param ulid Output buffer for generated ULID
/// @param timestamp_ms Timestamp in milliseconds (0 = use current time)
void ulid_generate_c(ulid_t* ulid, uint64_t timestamp_ms);

/// Encode ULID to string (26 characters + null terminator)
/// @param ulid Input ULID
/// @param output Output buffer (must be at least 27 bytes)
void ulid_encode_c(const ulid_t* ulid, char* output);

/// Decode ULID from string
/// @param str Input string (26 characters)
/// @param ulid Output buffer
/// @return 0 on success, -1 on error
int ulid_decode_c(const char* str, ulid_t* ulid);

#ifdef __cplusplus
}
#endif

#endif // ULID_WRAPPER_H

