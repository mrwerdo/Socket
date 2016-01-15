import PackageDescription
// Package information stuff.

let libraryTarget = Target(name: "Library")
let dev = Target(name: "dev", dependencies: [.Target(name: "Library")])

let package = Package(name: "SocketLib", targets: [libraryTarget, dev])

