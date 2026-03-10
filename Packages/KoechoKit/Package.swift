// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KoechoKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KoechoCore", targets: ["KoechoCore"]),
        .library(name: "KoechoPlatform", targets: ["KoechoPlatform"]),
    ],
    targets: [
        .target(name: "KoechoCore"),
        .target(name: "KoechoPlatform", dependencies: ["KoechoCore"]),
        .testTarget(name: "KoechoCoreTests", dependencies: ["KoechoCore"]),
        .testTarget(name: "KoechoPlatformTests", dependencies: ["KoechoPlatform", "KoechoCore"]),
    ]
)
