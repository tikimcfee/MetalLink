// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalLink",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MetalLink",
            targets: ["MetalLink"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tikimcfee/BitHandling.git", branch: "main"),
        .package(url: "https://github.com/christophhagen/BinaryCodable.git", exact: "2.0.1"),
    ],
    targets: [
        .target(
            name: "MetalLinkResources",
            dependencies: ["MetalLinkHeaders"],
            resources: [
                .process("Sources/Shaders"),
            ],
            publicHeadersPath: "."
        ),
        .target(
            name: "MetalLinkHeaders",
            publicHeadersPath: "."
        ),
        .target(
            name: "MetalLink",
            dependencies: [
                "MetalLinkResources",
                "BitHandling",
                "BinaryCodable"
            ]
        ),
        .testTarget(
            name: "MetalLinkTests",
            dependencies: [
                "MetalLink"
            ]
        ),
    ]
)
