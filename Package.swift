// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubtitleConverter",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SubtitleCore", targets: ["SubtitleCore"]),
        .executable(name: "SubtitleConverter", targets: ["SubtitleConverter"])
    ],
    targets: [
        .target(name: "SubtitleCore"),
        .executableTarget(name: "SubtitleConverter", dependencies: ["SubtitleCore"]),
        .testTarget(name: "SubtitleCoreTests", dependencies: ["SubtitleCore"])
    ]
)
