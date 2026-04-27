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
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit")
            ]
        ),
        .testTarget(
            name: "DelayNoMoreTests",
            dependencies: ["DelayNoMoreCore"]
        )
    ]
)
