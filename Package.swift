// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "HLS",
    products: [
        .library(
            name: "HLS",
            targets: ["HLS"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "HLS",
            dependencies: []),
        .testTarget(
            name: "HLSTests",
            dependencies: ["HLS"]),
    ]
)
