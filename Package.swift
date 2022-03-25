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
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "1.0.0"),
    .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
    .package(url: "https://github.com/kojirou1994/Units.git", from: "0.0.1"),
    .package(url: "https://github.com/kojirou1994/IntegerBytes.git", from: "0.0.1"),
    .package(url: "https://github.com/alexaubry/HTMLString.git", from: "5.0.0"),
    .package(url: "https://github.com/kojirou1994/Executable.git", from: "0.0.1"),
    .package(url: "https://github.com/kojirou1994/MediaUtility.git", from: "0.1.0"),
    .package(url: "https://github.com/swift-server/async-http-client.git", .exact("1.5.1")),
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
        .product(name: "Units", package: "Units"),
    ]),
    .target(
      name: "HLSDownloader",
      dependencies: [
        "HLS",
        "WebVTT",
        "HTTPDownloader",
        "Krypto",
        .product(name: "Algorithms", package: "swift-algorithms"),
        .product(name: "IntegerBytes", package: "IntegerBytes"),
    ]),
    .target(
      name: "Demo",
      dependencies: ["HLS", "HLSDownloader"]),
    .target(
      name: "hls-cli",
      dependencies: [
        "HLS",
        "HLSDownloader",
        .product(name: "AsyncHTTPClientProxy", package: "ProxyInfo"),
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
    .target(name: "CWebVTT"),
    .testTarget(
      name: "HLSTests",
      dependencies: ["HLS", "CWebVTT"]),
  ]
)
