import PackageDescription
// Package information stuff.

let libraryTarget = Target(name: "SocketLib")
let dev = Target(name: "dev", dependencies: [.Target(name: "SocketLib")])

let package = Package(name: "Socket", targets: [libraryTarget, dev])

