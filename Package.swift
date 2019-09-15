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
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.3.1"),
        .package(url: "git@github.com:kojirou1994/Remuxer.git", from: "0.0.1"),
        .package(url: "https://github.com/IBM-Swift/swift-html-entities.git", .branch("master")),
        .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "HLS",
            dependencies: ["KwiftUtility", "MediaTools", "HTMLEntities", "URLFileManager"]),
        .testTarget(
            name: "HLSTests",
            dependencies: ["HLS"]),
    ]
)
