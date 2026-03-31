// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenTwig",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OpenTwig", targets: ["OpenTwig"])
    ],
    dependencies: [
        .package(url: "https://github.com/SwiftGit2/SwiftGit2.git", branch: "main"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "OpenTwig",
            dependencies: [
                .product(name: "SwiftGit2", package: "SwiftGit2"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "OpenTwig",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "OpenTwigTests",
            dependencies: ["OpenTwig"],
            path: "OpenTwigTests"
        )
    ]
)
