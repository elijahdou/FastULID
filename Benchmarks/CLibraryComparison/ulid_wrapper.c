//
// ulid_wrapper.c
// C Library Wrapper Implementation
//
// Simple C implementation of ULID for benchmarking
// Based on the ULID specification: https://github.com/ulid/spec
//

#include "ulid_wrapper.h"
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <stdlib.h>

// Crockford's Base32 encoding table
static const char ENCODING_TABLE[32] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K',
    'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'X',
    'Y', 'Z'
};

// Decoding table (256 entries, 0xFF = invalid)
static const uint8_t DECODING_TABLE[256] = {
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
    0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00,
    0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C,
    0x1D, 0x1E, 0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    0xFF, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
    0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00,
    0x16, 0x17, 0x18, 0x19, 0x1A, 0xFF, 0x1B, 0x1C,
    0x1D, 0x1E, 0x1F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    [128 ... 255] = 0xFF
};

// Get current timestamp in milliseconds
static uint64_t get_timestamp_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000 + (uint64_t)tv.tv_usec / 1000;
}

// Generate random bytes
static void generate_random(uint8_t* buffer, size_t size) {
    arc4random_buf(buffer, size);
}

void ulid_generate_c(ulid_t* ulid, uint64_t timestamp_ms) {
    if (timestamp_ms == 0) {
        timestamp_ms = get_timestamp_ms();
    }
    
    // Pack timestamp (48 bits) into first 6 bytes
    ulid->bytes[0] = (timestamp_ms >> 40) & 0xFF;
    ulid->bytes[1] = (timestamp_ms >> 32) & 0xFF;
    ulid->bytes[2] = (timestamp_ms >> 24) & 0xFF;
    ulid->bytes[3] = (timestamp_ms >> 16) & 0xFF;
    ulid->bytes[4] = (timestamp_ms >> 8) & 0xFF;
    ulid->bytes[5] = timestamp_ms & 0xFF;
    
    // Generate random 80 bits (10 bytes)
    generate_random(&ulid->bytes[6], 10);
}

void ulid_encode_c(const ulid_t* ulid, char* output) {
    const uint8_t* bytes = ulid->bytes;
    
    // Encode 16 bytes to 26 Base32 characters
    output[0] = ENCODING_TABLE[bytes[0] >> 3];
    output[1] = ENCODING_TABLE[((bytes[0] & 0x07) << 2) | (bytes[1] >> 6)];
    output[2] = ENCODING_TABLE[(bytes[1] >> 1) & 0x1F];
    output[3] = ENCODING_TABLE[((bytes[1] & 0x01) << 4) | (bytes[2] >> 4)];
    output[4] = ENCODING_TABLE[((bytes[2] & 0x0F) << 1) | (bytes[3] >> 7)];
    output[5] = ENCODING_TABLE[(bytes[3] >> 2) & 0x1F];
    output[6] = ENCODING_TABLE[((bytes[3] & 0x03) << 3) | (bytes[4] >> 5)];
    output[7] = ENCODING_TABLE[bytes[4] & 0x1F];
    output[8] = ENCODING_TABLE[bytes[5] >> 3];
    output[9] = ENCODING_TABLE[((bytes[5] & 0x07) << 2) | (bytes[6] >> 6)];
    output[10] = ENCODING_TABLE[(bytes[6] >> 1) & 0x1F];
    output[11] = ENCODING_TABLE[((bytes[6] & 0x01) << 4) | (bytes[7] >> 4)];
    output[12] = ENCODING_TABLE[((bytes[7] & 0x0F) << 1) | (bytes[8] >> 7)];
    output[13] = ENCODING_TABLE[(bytes[8] >> 2) & 0x1F];
    output[14] = ENCODING_TABLE[((bytes[8] & 0x03) << 3) | (bytes[9] >> 5)];
    output[15] = ENCODING_TABLE[bytes[9] & 0x1F];
    output[16] = ENCODING_TABLE[bytes[10] >> 3];
    output[17] = ENCODING_TABLE[((bytes[10] & 0x07) << 2) | (bytes[11] >> 6)];
    output[18] = ENCODING_TABLE[(bytes[11] >> 1) & 0x1F];
    output[19] = ENCODING_TABLE[((bytes[11] & 0x01) << 4) | (bytes[12] >> 4)];
    output[20] = ENCODING_TABLE[((bytes[12] & 0x0F) << 1) | (bytes[13] >> 7)];
    output[21] = ENCODING_TABLE[(bytes[13] >> 2) & 0x1F];
    output[22] = ENCODING_TABLE[((bytes[13] & 0x03) << 3) | (bytes[14] >> 5)];
    output[23] = ENCODING_TABLE[bytes[14] & 0x1F];
    output[24] = ENCODING_TABLE[bytes[15] >> 3];
    output[25] = ENCODING_TABLE[bytes[15] & 0x1F];
    output[26] = '\0';
}

int ulid_decode_c(const char* str, ulid_t* ulid) {
    if (strlen(str) != 26) {
        return -1;
    }
    
    // Decode characters to 5-bit values
    uint8_t values[26];
    for (int i = 0; i < 26; i++) {
        uint8_t c = (uint8_t)str[i];
        if (c >= 128) return -1;
        
        uint8_t value = DECODING_TABLE[c];
        if (value == 0xFF) return -1;
        
        values[i] = value;
    }
    
    // Reconstruct 16 bytes
    ulid->bytes[0] = (values[0] << 3) | (values[1] >> 2);
    ulid->bytes[1] = (values[1] << 6) | (values[2] << 1) | (values[3] >> 4);
    ulid->bytes[2] = (values[3] << 4) | (values[4] >> 1);
    ulid->bytes[3] = (values[4] << 7) | (values[5] << 2) | (values[6] >> 3);
    ulid->bytes[4] = (values[6] << 5) | values[7];
    ulid->bytes[5] = (values[8] << 3) | (values[9] >> 2);
    ulid->bytes[6] = (values[9] << 6) | (values[10] << 1) | (values[11] >> 4);
    ulid->bytes[7] = (values[11] << 4) | (values[12] >> 1);
    ulid->bytes[8] = (values[12] << 7) | (values[13] << 2) | (values[14] >> 3);
    ulid->bytes[9] = (values[14] << 5) | values[15];
    ulid->bytes[10] = (values[16] << 3) | (values[17] >> 2);
    ulid->bytes[11] = (values[17] << 6) | (values[18] << 1) | (values[19] >> 4);
    ulid->bytes[12] = (values[19] << 4) | (values[20] >> 1);
    ulid->bytes[13] = (values[20] << 7) | (values[21] << 2) | (values[22] >> 3);
    ulid->bytes[14] = (values[22] << 5) | values[23];
    ulid->bytes[15] = (values[24] << 3) | values[25];
    
    return 0;
}

