// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftPlugin",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "SwiftPlugin",
            targets: ["SwiftPlugin"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-skills.git", from: "0.2.1"),
    ],
    targets: [
        .target(
            name: "SwiftPlugin",
            dependencies: [
                .product(name: "SwiftSkill", package: "swift-skills"),
            ]
        ),
        .testTarget(
            name: "SwiftPluginTests",
            dependencies: ["SwiftPlugin"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
