// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalLink",
    platforms: [
        .iOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MetalLink",
            targets: ["MetalLink"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tikimcfee/BitHandling.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "MetalLinkResources",
            dependencies: ["MetalLinkHeaders"],
            resources: [
                .process("Resources/Shaders"),
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
                "MetalLinkHeaders",
                "BitHandling"
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
