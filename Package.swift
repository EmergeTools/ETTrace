// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ETTrace",
    platforms: [.iOS(.v13), .macOS(.v12), .tvOS(.v13), .visionOS(.v1)],
    products: [
        .library(
            name: "ETTrace",
            type: .dynamic,
            targets: ["ETTrace"]
        ),
        .library(name: "Tracer", targets: ["Tracer"]),
        .library(name: "Symbolicator", targets: ["Symbolicator"]),
        .executable(
            name: "ETTraceRunner",
            targets: ["ETTraceRunner"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/EmergeTools/peertalk.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/httpswift/swifter.git", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "ETTrace",
            dependencies: [
                "Tracer",
                "CommunicationFrame",
                .product(name: "Peertalk", package: "peertalk")
            ],
            path: "ETTrace/ETTrace",
            publicHeadersPath: "Public"
        ),
        .target(
          name: "Tracer",
          dependencies: [
              "Unwinding",
              "TracerSwift"
          ],
          path: "ETTrace/Tracer",
          publicHeadersPath: "Public"
        ),
        .target(
          name: "TracerSwift",
          dependencies: [
              "Unwinding",
          ],
          path: "ETTrace/TracerSwift"
        ),
        .target(name: "Symbolicator", dependencies: ["ETModels"], path: "ETTrace/Symbolicator"),
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
        .executableTarget(
            name: "ETTraceRunner",
            dependencies: [
                "CommunicationFrame",
                "JSONWrapper",
                "ETModels",
                "Symbolicator",
                .product(name: "Peertalk", package: "peertalk"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Swifter", package: "swifter")
            ],
            path: "ETTrace/ETTraceRunner",
            exclude: [
                "ETTraceRunner.entitlements"
            ]
        ),
        .target(
            name: "JSONWrapper",
            dependencies: [
                "ETModels"
            ],
            path: "ETTrace/JSONWrapper",
            publicHeadersPath: "Public"
        ),
        .target(
            name: "ETModels",
            dependencies: [],
            path: "ETTrace/ETModels"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
