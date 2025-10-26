// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SimpleOverlaySystem",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "SimpleOverlaySystem",
            targets: ["SimpleOverlaySystem"]
        )
    ],
    targets: [
        .target(
            name: "SimpleOverlaySystem"
        ),
        .testTarget(
            name: "SimpleOverlaySystemTests",
            dependencies: ["SimpleOverlaySystem"]
        )
    ]
)
