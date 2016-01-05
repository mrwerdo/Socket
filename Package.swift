import PackageDescription
// Package information stuff.

let libraryTarget = Target(name: "SocketLib")
let sockdev = Target(name: "sockdev", dependencies: [.Target(name: "SocketLib")])

let package = Package(name: "Socket", targets: [libraryTarget, sockdev])

