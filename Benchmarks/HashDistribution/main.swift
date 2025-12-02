import Foundation
import FastULID

// Simple statistical analysis
func analyzeHashDistribution(count: Int, buckets: Int) {
    print("Generating \(count) ULIDs and hashing into \(buckets) buckets...")
    
    var bucketCounts = [Int](repeating: 0, count: buckets)
    let generator = ULIDGenerator()
    
    // Generate and bucket
    for _ in 0..<count {
        let ulid = try! generator.generate()
        let hash = ulid.hashValue
        // Handle negative hash values correctly for modulo
        let index = abs(hash) % buckets
        bucketCounts[index] += 1
    }
    
    // Analyze
    let expected = Double(count) / Double(buckets)
    var chiSquare = 0.0
    var minCount = Int.max
    var maxCount = Int.min
    
    for c in bucketCounts {
        let diff = Double(c) - expected
        chiSquare += (diff * diff) / expected
        
        if c < minCount { minCount = c }
        if c > maxCount { maxCount = c }
    }
    
    print("\nResults:")
    print("- Total Items: \(count)")
    print("- Buckets: \(buckets)")
    print("- Expected per bucket: \(Int(expected))")
    print("- Min count: \(minCount) (Deviation: \(String(format: "%.2f", Double(minCount - Int(expected)) / expected * 100))%)")
    print("- Max count: \(maxCount) (Deviation: \(String(format: "%.2f", Double(maxCount - Int(expected)) / expected * 100))%)")
    
    // Chi-Square Test interpretation (degrees of freedom = buckets - 1)
    // Lower is better (closer to uniform distribution)
    print("- Chi-Square Statistic: \(String(format: "%.2f", chiSquare))")
    
    let variancePercent = (Double(maxCount - minCount) / expected) * 100
    print("- Max-Min Spread: \(String(format: "%.2f", variancePercent))%")
    
    if variancePercent < 5.0 {
        print("\n✅ Conclusion: Distribution is VERY UNIFORM.")
    } else if variancePercent < 10.0 {
        print("\n⚠️ Conclusion: Distribution is FAIRLY UNIFORM.")
    } else {
        print("\n❌ Conclusion: Distribution shows significant bias.")
    }
}

// Run tests for different bucket sizes
print("--- Test 1: Small Modulo (e.g., Database Sharding) ---")
analyzeHashDistribution(count: 1_000_000, buckets: 16)

print("\n--- Test 2: Medium Modulo (e.g., Hash Map) ---")
analyzeHashDistribution(count: 1_000_000, buckets: 1024)

print("\n--- Test 3: Large Modulo (e.g., Large Cache) ---")
analyzeHashDistribution(count: 1_000_000, buckets: 65536)
