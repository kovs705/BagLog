// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BagLogPackage",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "AppShellFeature", targets: ["AppShellFeature"]),
        .library(name: "Persistence", targets: ["Persistence"])
    ],
    targets: [
        .target(name: "AppShellFeature"),
        .target(name: "Persistence"),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"])
    ]
)
