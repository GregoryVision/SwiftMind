// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "SwiftMind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "swiftmind", targets: ["CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: []
        ),
        .executableTarget(
            name: "CLI",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
//                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        ),
        .target(name: "XcodeExtension",
                dependencies: ["Core"])
    ]
)
