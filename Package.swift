// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SoloStyle",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(
            name: "SoloStyle",
            targets: ["SoloStyle"]
        ),
    ],
    dependencies: [
        // Add external dependencies here if needed
        // .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0"),
    ],
    targets: [
        .target(
            name: "SoloStyle",
            dependencies: [],
            path: "SoloStyle"
        ),
        .testTarget(
            name: "SoloStyleTests",
            dependencies: ["SoloStyle"],
            path: "SoloStyleTests"
        ),
    ]
)
