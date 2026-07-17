// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "chapterize",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "ChapterizeKit"),
        .executableTarget(
            name: "chapterize",
            dependencies: [
                "ChapterizeKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "ChapterizeKitTests", dependencies: ["ChapterizeKit"]),
    ]
)
