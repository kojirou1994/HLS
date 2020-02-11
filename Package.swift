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
        .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.5.1"),
        .package(url: "git@github.com:kojirou1994/Executable.git", from: "0.0.1"),
        .package(url: "https://github.com/alexaubry/HTMLString.git", from: "5.0.0"),
        .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
        .package(url: "git@github.com:kojirou1994/MediaUtility.git", from: "0.0.1")
    ],
    targets: [
        .target(
            name: "HLS",
            dependencies: ["KwiftUtility", "Executable", "MediaTools", "HTMLString", "URLFileManager"]),
        .testTarget(
            name: "HLSTests",
            dependencies: ["HLS"]),
    ]
)
