// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FastULID",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "FastULID",
            targets: ["FastULID"])
    ],
    targets: [
        // Main library
        .target(
            name: "FastULID"),
        
        // Tests
        .testTarget(
            name: "FastULIDTests",
            dependencies: ["FastULID"]),
        
        // Main benchmark
        .executableTarget(
            name: "FastULIDBenchmark",
            dependencies: ["FastULID"],
            path: "Benchmarks/FastULIDBenchmark"),
        
        // Correctness validation
        .executableTarget(
            name: "CorrectnessBenchmark",
            dependencies: ["FastULID"],
            path: "Benchmarks/CorrectnessBenchmark"),
        
        // Hash Distribution Test
        .executableTarget(
            name: "HashDistribution",
            dependencies: ["FastULID"],
            path: "Benchmarks/HashDistribution"),
        
        // Cross Language Validation
        .executableTarget(
            name: "CrossLanguageValidation",
            dependencies: ["FastULID"],
            path: "Benchmarks/CrossLanguageValidation"),
        
        // Comparison benchmarks
        // Note: Requires manual setup - see respective directories for instructions
        
        // yaslab/ULID.swift comparison
        // Uncomment after adding yaslab/ULID.swift dependency
        // .executableTarget(
        //     name: "YaslabComparison",
        //     dependencies: ["FastULID"],
        //     path: "Benchmarks/YaslabComparison"),
        
        // C library comparison
        .target(
            name: "CULIDWrapper",
            path: "Benchmarks/CLibraryComparison",
            sources: ["ulid_wrapper.c"],
            publicHeadersPath: "."),
        .executableTarget(
            name: "CLibraryComparison",
            dependencies: ["FastULID", "CULIDWrapper"],
            path: "Benchmarks/CLibraryComparison",
            exclude: ["ulid_wrapper.c", "ulid_wrapper.h", "module.modulemap"])
    ]
)
