// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "HLS",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .library(name: "MPD", targets: ["MPD"]),
    .library(
      name: "HLS",
      targets: ["HLS"]),
    .library(
      name: "WebVTT",
      targets: ["WebVTT"]),
    .library(
      name: "HLSDownloader",
      targets: ["HLSDownloader"])
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.8.0"),
    .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
    .package(url: "https://github.com/alexaubry/HTMLString.git", from: "5.0.0"),
    .package(url: "https://github.com/kojirou1994/Executable.git", from: "0.0.1"),
    .package(url: "https://github.com/kojirou1994/MediaUtility.git", from: "0.1.0"),
    .package(url: "https://github.com/kojirou1994/HTTPDownloader.git", .branch("master")),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(url: "https://github.com/kojirou1994/Krypto.git", .branch("main")),
    .package(url: "https://github.com/kojirou1994/ProxyInfo.git", from: "0.0.1"),
    .package(url: "https://github.com/vincent-pradeilles/KeyPathKit.git", from: "1.0.0"),
    .package(url: "https://github.com/MaxDesiatov/XMLCoder.git", .upToNextMajor(from: "0.13.0")),
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.13.0")
  ],
  targets: [
    .target(
      name: "MPD",
      dependencies: [
        .product(name: "XMLCoder", package: "XMLCoder"),
      ]),
    .target(
      name: "mpd-code",
      dependencies: [
        "MPD",
        .product(name: "XMLCoder", package: "XMLCoder"),
      ]),
    .target(
      name: "WebVTT",
      dependencies: [
        .product(name: "MediaTools", package: "MediaUtility"),
        "HTMLString",
    ]),
    .target(
      name: "HLS",
      dependencies: [
        .product(name: "KwiftUtility", package: "Kwift"),
        "Executable",
        .product(name: "MediaTools", package: "MediaUtility"),
        "HTMLString",
        "URLFileManager",
        .product(name: "Logging", package: "swift-log"),
        "KeyPathKit",
    ]),
    .target(
      name: "HLSDownloader",
      dependencies: [
        "HLS",
        "WebVTT",
        "HTTPDownloader",
        "Krypto",
        .product(name: "Algorithms", package: "swift-algorithms"),
    ]),
    .target(
      name: "Demo",
      dependencies: ["HLS", "HLSDownloader"]),
    .target(
      name: "hls-cli",
      dependencies: [
        "HLS",
        "HLSDownloader",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
    .target(
      name: "tver-cli",
      dependencies: [
        "MPD",
        "URLFileManager",
        .product(name: "KwiftUtility", package: "Kwift"),
        .product(name: "AsyncHTTPClientProxy", package: "ProxyInfo"),
        .product(name: "ExecutableLauncher", package: "Executable"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "SQLite", package: "SQLite.swift"),
      ]),
    .testTarget(
      name: "HLSTests",
      dependencies: ["HLS"]),
  ]
)
