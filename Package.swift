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
        // Shared fixtures are built only by the test targets; no library product exposes them.
        .target(
            name: "NetworkTestSupport",
            dependencies: ["NetworkClient", "NetworkUtilities"],
            path: "Tests/NetworkTestSupport"
        ),
        .testTarget(
            name: "NetworkClientTests",
            dependencies: ["NetworkClient", "NetworkTestSupport"]
        ),
        .testTarget(
            name: "NetworkStreamTests",
            dependencies: ["NetworkStream", "NetworkTestSupport"]
        ),
        .testTarget(
            name: "NetworkUtilitiesTests",
            dependencies: ["NetworkUtilities", "NetworkTestSupport"]
        )
    ],
    swiftLanguageModes: [.v6],
)
