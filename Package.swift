// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ETTrace",
    products: [
        .library(
            name: "ETTrace",
            type: .dynamic,
            targets: ["ETTrace"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/EmergeTools/peertalk.git", branch: "feature/spm")
    ],
    targets: [
        .target(
            name: "ETTrace",
            dependencies: [
                "Unwinding",
                "CommunicationFrame",
                .product(name: "Peertalk", package: "peertalk")
            ],
            path: "ETTrace/ETTrace",
            publicHeadersPath: "Public"
        ),
        .target(
            name: "CommunicationFrame",
            path: "ETTrace/CommunicationFrame",
            publicHeadersPath: "Public"
        ),
        .target(
            name: "Unwinding",
            dependencies: [],
            path: "Unwinding/Crashlytics",
            exclude: [
                "LICENSE",
                "README.md"
            ],
            publicHeadersPath: "Public"
        ),
        
    ]
)
