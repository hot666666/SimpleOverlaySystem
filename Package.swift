// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SimpleOverlaySystem",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .macCatalyst(.v17),
    .tvOS(.v17),
  ],
  products: [
    .library(
      name: "SimpleOverlaySystem",
      targets: ["SimpleOverlaySystem"]
    )
  ],
  dependencies: [
    // DocC plugin enables `swift package generate-documentation`
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
  ],
  targets: [
    .target(
      name: "SimpleOverlaySystem"
    ),
    .testTarget(
      name: "SimpleOverlaySystemTests",
      dependencies: ["SimpleOverlaySystem"]
    ),
  ]
)
