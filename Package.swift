// swift-tools-version:5.5
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
            dependencies: ["NetworkClient"]),
        .testTarget(
            name: "NetworkUtilitiesTests",
            dependencies: ["NetworkUtilities"])
    ]
)
