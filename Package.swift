// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GenerateInterface",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "509.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.3.0"),
        .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.36.0")
    ],
    targets: [
        .executableTarget(
            name: "generateInterface",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
            ]),
        .testTarget(
            name: "GenerateInterfaceTests",
            dependencies: [
                "generateInterface",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ])
    ]
)
