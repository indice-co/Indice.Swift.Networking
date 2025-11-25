// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkClient",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "NetworkUtilities",
            targets: ["NetworkUtilities"]),
        .library(
            name: "NetworkClient",
            targets: ["NetworkClient"]),
    ],
    targets: [
        .target(
            name: "NetworkUtilities"
        ),
        .target(
            name: "NetworkClient",
            dependencies: ["NetworkUtilities"]
        ),
        .testTarget(
            name: "NetworkClientTests",
            dependencies: ["NetworkClient"]
        ),
        .testTarget(
            name: "NetworkUtilitiesTests",
            dependencies: ["NetworkUtilities"]
        )
    ],
    swiftLanguageModes: [.v6],
)
