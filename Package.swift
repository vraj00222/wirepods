// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WirePods",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "WirePodsCore", targets: ["WirePodsCore"])
    ],
    targets: [
        .target(
            name: "WirePodsCore",
            path: "Shared/Sources/WirePodsCore"
        ),
        .testTarget(
            name: "WirePodsCoreTests",
            dependencies: ["WirePodsCore"],
            path: "Shared/Tests"
        )
    ]
)
