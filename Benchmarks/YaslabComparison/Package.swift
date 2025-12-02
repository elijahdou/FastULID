// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YaslabComparison",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    dependencies: [
        // Our optimized ULID
        .package(path: "../.."),
        
        // Original yaslab/ULID.swift
        .package(url: "https://github.com/yaslab/ULID.swift.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "YaslabComparison",
            dependencies: [
                .product(name: "FastULID", package: "ulid"),
                .product(name: "ULID", package: "ULID.swift")
            ],
            path: ".")
    ]
)

