import Foundation
import FastULID

func generate(count: Int) {
    print("Generating \(count) ULIDs from Swift...")
    for _ in 0..<count {
        print(ULID().ulidString)
    }
}

func validate() {
    print("Validating ULIDs in Swift...")
    var validCount = 0
    var totalCount = 0
    
    while let line = readLine() {
        let ulidStr = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if ulidStr.isEmpty { continue }
        
        // Ignore non-ULID lines (e.g. logs)
        if ulidStr.count != 26 { continue }
        
        totalCount += 1
        if let ulid = ULID(ulidString: ulidStr) {
            // Check if we can extract timestamp (basic sanity check)
            let _ = ulid.timestamp
            validCount += 1
        } else {
            print("  \(ulidStr) -> Invalid format")
        }
    }
    
    print("Swift Validation Results: \(validCount)/\(totalCount) valid")
    if validCount == totalCount && totalCount > 0 {
        exit(0)
    } else {
        exit(1)
    }
}

let args = ProcessInfo.processInfo.arguments
if args.count < 2 {
    print("Usage: CrossLanguageValidation [generate <count>|validate]")
    exit(1)
}

let mode = args[1]

if mode == "generate" {
    let count = args.count > 2 ? Int(args[2]) ?? 10 : 10
    generate(count: count)
} else if mode == "validate" {
    validate()
} else {
    print("Unknown mode: \(mode)")
    exit(1)
}

