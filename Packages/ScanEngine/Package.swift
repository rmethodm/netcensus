// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ScanEngine",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "ScanEngine", targets: ["ScanEngine"]),
        .library(name: "ScanEngineMocks", targets: ["ScanEngineMocks"]),
        .executable(name: "scanctl", targets: ["Scanctl"]),
    ],
    targets: [
        .executableTarget(
            name: "Scanctl",
            dependencies: ["ScanEngine"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "ScanEngine",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("Security"),
            ]
        ),
        .target(
            name: "ScanEngineMocks",
            dependencies: ["ScanEngine"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "ScanEngineTests",
            dependencies: ["ScanEngine", "ScanEngineMocks"]
        ),
    ]
)
