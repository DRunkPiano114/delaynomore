// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DelayNoMore",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DelayNoMore", targets: ["DelayNoMoreApp"]),
        .library(name: "DelayNoMoreCore", targets: ["DelayNoMoreCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .target(name: "DelayNoMoreCore"),
        .target(
            name: "DelayNoMoreAppResources",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "DelayNoMoreApp",
            dependencies: [
                "DelayNoMoreCore",
                "DelayNoMoreAppResources",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "DelayNoMoreTests",
            dependencies: ["DelayNoMoreCore"]
        )
    ]
)
