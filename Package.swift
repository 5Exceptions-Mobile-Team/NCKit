// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NCKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NCKit",
            targets: ["NCKit"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "NCKit",
            path: "NCKit.xcframework"
        )
    ]
)
