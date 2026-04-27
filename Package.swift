// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DelayNoMore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DelayNoMore", targets: ["DelayNoMoreApp"]),
        .library(name: "DelayNoMoreCore", targets: ["DelayNoMoreCore"])
    ],
    targets: [
        .target(name: "DelayNoMoreCore"),
        .executableTarget(
            name: "DelayNoMoreApp",
            dependencies: ["DelayNoMoreCore"],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "DelayNoMoreTests",
            dependencies: ["DelayNoMoreCore"]
        )
    ]
)
