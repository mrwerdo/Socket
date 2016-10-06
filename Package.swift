import PackageDescription

let package = Package(
    name: "Socket",
    targets: [ // ]
        Target(name: "Support"),
        Target(name: "Socket", dependencies: ["Support"])
    ]
)
