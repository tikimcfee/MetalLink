// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalLink",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "MetalLink",
            targets: ["MetalLink"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tikimcfee/BitHandling.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MetalLinkHeaders",
            publicHeadersPath: "."
        ),
        .target(
            name: "MetalLink",
            dependencies: [
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
