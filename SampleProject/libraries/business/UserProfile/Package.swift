// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UserProfile",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "UserProfile", targets: ["UserProfile"]),
    ],
    targets: [
        .target(name: "UserProfile"),
    ]
)
