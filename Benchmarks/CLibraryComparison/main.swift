//
// main.swift  
// CLibraryComparison
//
// Created on 2025-12-02.
// Copyright © 2025 author elijah. All rights reserved.
//
// 2. Build the C library
// 3. Create module.modulemap
// 4. Update Package.swift with system library target
//

import Foundation
import FastULID

print("""
╔════════════════════════════════════════════════════════════════════════════════╗
║                                                                                ║
║                    C ULID Library Comparison Benchmark                         ║
║                                                                                ║
║  Purpose: Compare Swift implementation against C library performance           ║
║                                                                                ║
║  Status: ⚠️ C library integration not configured                               ║
║                                                                                ║
║  To enable:                                                                    ║
║  1. Install C ULID library:                                                    ║
║     git clone https://github.com/suyash/ulid                                   ║
║     cd ulid && make                                                            ║
║                                                                                ║
║  2. Create module map (module.modulemap):                                      ║
║     module CULID {                                                             ║
║       header "ulid.h"                                                          ║
║       link "ulid"                                                              ║
║       export *                                                                 ║
║     }                                                                           ║
║                                                                                ║
║  3. Add to Package.swift:                                                      ║
║     .systemLibrary(name: "CULID", path: "Sources/CULID")                       ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝

""")

// Test Swift ULID works
print("✅ Testing Swift ULID...")
for i in 1...5 {
    let ulid = ULID()
    print("  \(i). \(ulid.ulidString)")
}

print("\n📊 Swift ULID is working correctly!")
print("🔧 Add C library integration to enable comparison benchmarks.")
