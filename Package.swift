// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkClient",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "NetworkClient",
            targets: ["NetworkClient"]),
        .library(
            name: "NetworkStream",
            targets: ["NetworkStream"]),
    ],
    dependencies: [
        .package(url: "https://github.com/indice-co/Indice.HTTP.Swift", .upToNextMajor(from: "1.0.0"))
    ],
    targets: [
        .target(
            name: "NetworkClient",
            dependencies: [
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift")
            ]
        ),
        .target(
            name: "NetworkStream",
            dependencies: [
                "NetworkClient",
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift")]
        ),
        // Shared fixtures are built only by the test targets; no library product exposes them.
        .target(
            name: "NetworkTestSupport",
            dependencies: [
                "NetworkClient",
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift")],
            path: "Tests/NetworkTestSupport"
        ),
        .testTarget(
            name: "NetworkClientTests",
            dependencies: [
                "NetworkClient",
                "NetworkTestSupport",
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift")],
        ),
        .testTarget(
            name: "NetworkStreamTests",
            dependencies: [
                "NetworkStream",
                "NetworkTestSupport",
                .product(name: "NetworkUtilities", package: "Indice.HTTP.Swift")],
        ),
    ],
    swiftLanguageModes: [.v6],
)
