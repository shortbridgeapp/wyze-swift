// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WyzeSwift",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16)
    ],
    products: [
        .library(
            name: "WyzeSwift",
            targets: ["WyzeSwift"]
        ),
    ],
    targets: [
        .target(
            name: "WyzeSwift",
            dependencies: []
        )
    ]
)
