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
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.2.0"),
        .package(path: "../Remuxer"),
        .package(url: "https://github.com/IBM-Swift/swift-html-entities.git", .branch("master")),
    ],
    targets: [
        .target(
            name: "HLS",
            dependencies: ["MediaTools", "Kwift", "MplsReader", "HTMLEntities"]),
        .testTarget(
            name: "HLSTests",
            dependencies: ["HLS"]),
    ]
)
