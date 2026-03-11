// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mLogger",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "mLogger",
            type: .dynamic,
            targets: ["mLogger"]
        ),
    ],
    targets: [
        .target(
            name: "mLogger",
            path: "Sources"
        ),
        .testTarget(
            name: "mLoggerTests",
            dependencies: ["mLogger"],
            path: "Tests"
        ),
    ]
)
