import PackageDescription

var targets: [Target] = []
/// The public interface to the library
targets.append(Target(name: "SocketLib"))
let package = Package(name: "Socket", targets: targets)

