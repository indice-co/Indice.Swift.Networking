// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IndiceNetworkClient",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "IndiceNetworkClient",
            targets: ["IndiceNetworkClient"]),
    ],
    targets: [
        .target(
            name: "IndiceNetworkClient",
            dependencies: []),
        .testTarget(
            name: "IndiceNetworkClientTests",
            dependencies: ["IndiceNetworkClient"]),
    ]
)
