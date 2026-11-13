// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stark",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "Stark", targets: ["Stark"])
    ],
    targets: [
        .executableTarget(
            name: "Stark",
            path: "Sources/Stark",
            resources: [.process("Resources")]
        )
    ]
)
