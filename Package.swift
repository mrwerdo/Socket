import PackageDescription
import Darwin

var targets: [Target] = []
/// The public interface to the library
targets.append(Target(name: "SocketLib"))

var buffer = [CChar](count: 1024, repeatedValue: 0)
if let workingDir = String.fromCString(getcwd(&buffer, 1024))
{
    if access ("./Sources/dev/main.swift", F_OK) != -1 {
        /// My developer environment - it's private
        let dev = Target(name: "dev", dependencies: [.Target(name: "SocketLib")])
        targets.append(dev)
    }
}

let package = Package(name: "Socket", targets: targets)

