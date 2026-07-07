// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BarricadeAdvisor",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QuoridorCore"),
        .executableTarget(
            name: "BarricadeAdvisor",
            dependencies: ["QuoridorCore"]
        ),
        .testTarget(
            name: "QuoridorCoreTests",
            dependencies: ["QuoridorCore"]
        ),
    ]
)
