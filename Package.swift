// swift-tools-version:5.2

import PackageDescription

let package = Package(
  name: "HLS",
  products: [
    .library(
      name: "HLS",
      targets: ["HLS"]),
    .library(
      name: "WebVTT",
      targets: ["WebVTT"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kojirou1994/Kwift.git", from: "0.5.1"),
    .package(url: "git@github.com:kojirou1994/Executable.git", from: "0.0.1"),
    .package(url: "https://github.com/alexaubry/HTMLString.git", from: "5.0.0"),
    .package(url: "https://github.com/kojirou1994/URLFileManager.git", from: "0.0.3"),
    .package(url: "git@github.com:kojirou1994/MediaUtility.git", from: "0.0.1"),
    .package(url: "git@github.com:kojirou1994/HTTPDownloader.git", .branch("master"))
  ],
  targets: [
    .target(
      name: "WebVTT",
      dependencies: [
        .product(name: "MediaTools", package: "MediaUtility"),
        "HTMLString"
    ]),
    .target(
      name: "HLS",
      dependencies: [
        .product(name: "KwiftUtility", package: "Kwift"),
        "Executable",
        .product(name: "MediaTools", package: "MediaUtility"),
        "HTMLString",
        "URLFileManager"
    ]),
    .target(
      name: "Demo",
      dependencies: ["HLS"]),
    .testTarget(
      name: "HLSTests",
      dependencies: ["HLS"]),
  ]
)
