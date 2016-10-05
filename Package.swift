import PackageDescription

let package = Package(
    name: "iSocket",
    targets: [ // ]
        Target(name: "Support"),
        Target(name: "Socket", dependencies: ["Support"])
    ]
)
