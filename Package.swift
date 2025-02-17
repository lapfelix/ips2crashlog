import PackageDescription

let package = Package(
    name: "ips2crashlog",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/tristanhimmelman/ObjectMapper.git", from: "4.4.3")
    ],
    targets: [
        .executableTarget(
            name: "ips2crashlog",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "ObjectMapper"
            ],
            path: "Sources/ips2crashlog"
        ),
        .testTarget(
            name: "ips2crashlogTests",
            dependencies: ["ips2crashlog"],
            resources: [
                .copy("TestResources/source.ips"),
                .copy("TestResources/target.txt")
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)
