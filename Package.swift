// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkClient",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "NetworkUtilities",
            targets: ["NetworkUtilities"]),
        .library(
            name: "NetworkClient",
            targets: ["NetworkClient"]),
        .library(
            name: "NetworkStream",
            targets: ["NetworkStream"]),
    ],
    targets: [
        .target(
            name: "NetworkUtilities"
        ),
        .target(
            name: "NetworkClient",
            dependencies: ["NetworkUtilities"]
        ),
        .target(
            name: "NetworkStream",
            dependencies: [
                "NetworkClient",
                "NetworkUtilities"]
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
