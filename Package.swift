// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalLink",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "MetalLink",
            targets: ["MetalLink"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tikimcfee/BitHandling.git", branch: "sgalpha-bits"),
        .package(url: "https://github.com/schwa/MetalCompilerPlugin", branch: "main")
    ],
    targets: [
//        .target(
//            name: "MetalLinkResources",
//            plugins: [
//                .plugin(name: "MetalCompilerPlugin", package: "MetalCompilerPlugin")
//            ]
//        ),
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
