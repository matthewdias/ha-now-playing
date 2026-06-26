// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HANowPlaying",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/kean/Nuke", from: "13.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "HANowPlaying",
            dependencies: [
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/HANowPlaying"
        ),
        .testTarget(
            name: "HANowPlayingTests",
            dependencies: ["HANowPlaying"],
            path: "Tests/HANowPlayingTests"
        ),
    ]
)
