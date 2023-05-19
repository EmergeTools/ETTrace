// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ETTrace",
    products: [
        .library(
            name: "ETTrace",
            targets: ["ETTrace"]),
    ],
    targets: [
        .binaryTarget(
            name: "ETTrace",
            path: "./Prebuilt/ETTrace.xcframework"
        ),
    ]
)
