// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RiseCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "RiseCore", targets: ["RiseCore"])
    ],
    targets: [
        .target(name: "RiseCore"),
        .executableTarget(name: "RiseCoreCheck", dependencies: ["RiseCore"]),
        .testTarget(name: "RiseCoreTests", dependencies: ["RiseCore"])
    ]
)
