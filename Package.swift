// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenTwig",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "OpenTwig",
            dependencies: [
                .product(name: "SwiftSoup", package: "SwiftSoup"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "OpenTwig",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
