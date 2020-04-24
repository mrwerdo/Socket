// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "Socket",
    products: [
        .library(name: "Socket", targets: ["Socket"])
    ],
    targets: [
        .target(name: "Support"),
        .target(name: "Socket", dependencies: ["Support"]),
        .testTarget(name: "SocketTests", dependencies: ["Socket"])
    ]
)
