// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FlickSlidesKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        .library(
            name: "FlickSlidesKit",
            targets: ["FlickSlidesKit"]
        ),
    ],
    targets: [
        .target(
            name: "FlickSlidesKit",
            path: "Sources/FlickSlidesKit"
        ),
        .testTarget(
            name: "FlickSlidesKitTests",
            dependencies: ["FlickSlidesKit"],
            path: "Tests/FlickSlidesKitTests"
        ),
    ]
)
