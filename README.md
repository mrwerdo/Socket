# Swift-Sockets
A low level socket library written in swift for beaming data across the internet!

# Description
Swift-Sockets is a socket wrapper for the BSD C socket layer. It provides convenient access to the socket layer, allowing various types of connections to be created. Swift-Sockets also embraces Swift`s new error model, allowing for advanced error handling while still maintaining easy to read code.

# What can you do?

Send data accross the internet. Seriously.

Specifically, I've tested:
- Sending data over a TCP & UDP connection to python
- Recieving data over a TCP & UDP connection from python
- Getting the host name
- Setting the host name (requires root)
- Resolving host names using getaddrinfo

More will come in the future.

# How do you use it?

To create, connect and send data on a TCP socket do:
```
let data = "Hello, TCP!"
let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
try socket.send(data)
try socket.close()
```

To create and send data over a UDP socket, do:
```
let data = "Hello, UDP!"
let destinationHost = "localhost"
let socket = try Socket(domain: .INET, type: .Datagram, proto: .UDP)
for address in try getaddrinfo(host: destinationHost, service: nil, hints: &socket.address.addrinfo) {
    do {
        let length = data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        try address.setPort(500)
        try socket.sendTo(address, data: data, length: length)
        break // only send once
    } catch {
        continue
    }
}
try socket.close()
```

Recieving data is just as simple...

For a TCP socket, do:
```
let sendingHost = "localhost"
let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
try socket.connectTo(host: sendingHost, port: 5000)

do {
    guard let message = try socket.recv(1024) else {
        return // connection closed
    }
    if let data = String.fromCString(UnsafePointer(message.data)) {
        print("New message \(message.length) bytes long: \(data)")
    } else {
        print("Error decoding message!")
    }
} catch SocketError.RecvTryAgain {
    // non-fatal error, try again some time since no data available
}
try socket.close()
```

For a UDP socket, do:
```
let recievingHost = "localhost"
let socket = try Socket(domain: .INET, type: .Stream, proto: .UDP)
try socket.bindTo(host: recievingHost, port: 5000)

do {
    let message = try socket.recv(1024)! // UDP is connectionless
    if let data = String.fromCString(UnsafePointer(message.data)) {
        print("New message \(message.length) bytes long: \(data)")
    } else {
        print("Error decoding message!")
    }
} catch SocketError.RecvTryAgain {
    // non-fatal error, try again some time since no data available
}
try socket.close()
```

# How do I get started?

This project is compatiable with the [swift package manager](https://swift.org/package-manager/). To use it in your project,
add a dependency to your project as such:

```
import PackageDescription

let package = Package(name: "An Example Projcet", 
  dependencies: [
	  .Package(url: "https://github.com/mrwerdo/swift-sockets.git", versions: Version(1,0,0)..<Version(2,0,0))
		]
)	
```
The url should point to **this** repository, using https. The name parameter is the name of your project.

Finally, for those of you who don't really know anythng about the swift package manager, create a file named Package.swift and put the above code in it. This bascially a manifest file. Change the program name if you want, etc. Then create a file named main.swift. Put this in it:
```
import Socket
let hostname = try gethostname()
print(hostname)
```
Then run `$ swift build`, then run the output executable (i.e. `$ .build/debug/programname`), and you shoud see the hostname of your computer.

# Error Handling

Almost every function throws their own specific error case, allowing for very precise error handling. As such, it is easy to identify which function calls were the cause of the error and respond appropriately.

This approach is not without reason. Every C function which is being called all return many errors, and since this is a library, it is appropriate to return these errors to the caller and let them deal with it.

So how does this work? Below is a realtivly full example of error handling for a TCP server. This is a simple fail approch to handling any errors - as soon as an error occurs, fail.
```
do {
    let recievingHost = "localhost"
    var shouldRun = true

    let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
    try socket.setShouldReuseAddress(true)
    try socket.bindTo(host: recievingHost, port: 5000)
    try socket.listen(5)

    mainLoop: while shouldRun {
        let client = try socket.accept()
    
        recvLoop: while true {
            do {
                guard let message = try client.recv(1024) else {
                    try client.close()
                    break recvLoop
                }
                if let data = String.fromCString(UnsafePointer(message.data)) {
                    switch data {
                        case "STOP":
                        shouldRun = false
                        break recvLoop
                    default:
                        print("New message \(message.length) bytes long: \(data)")
                    }
                } else {
                    print("Error decoding message!")
                }
            } catch SocketError.RecvTryAgain {
                continue recvLoop   
            }
        }
        try client.send("Goodbye!")
        try client.close()
    }
    try socket.close()
} catch let e as SocketError {
    func emsg(n: Int32) -> String {
    return String.fromCError(n)
    }
    switch e {
    case .CreationFailed(let n):
        print("Could not create socket: \(emsg(n))")
    case .BindFailed(let n):
        print("Bind failed: \(emsg(n))")
    case .ListenFailed(let n):
        print("Listen failed: \(emsg(n))")
    case .AcceptFailed(let n):
        print("Accept failed: \(emsg(n))")
    case .RecvFromFailed(let n):
        print("Recieve from failed: \(emsg(n))")
    case .SendToFailed(let n):
        print("Send failed: \(emsg(n))")
    case .CloseFailed(let n):
        print("Close failed: \(emsg(n))")
    case .ParameterError(let reason):
        print("Invalid parameter: \(reason)")
    case .SetSocketOptionFailed(let n):
        print("Setting socket options failed: \(emsg(n))")
    case .NoAddressesFound(let reason, let errors):
        print("No addresses found: \(reason)", terminator: "; ")
        print("Reasons:", terminator: "")
        errors.dropLast().forEach { print(emsg($0), terminator: ", ") }
        if let last = errors.last {
            print(emsg(last))
        }
    default:
        print("Unknown handled error: \(e)")
    }
} catch {
    errmsg(error) // other, possible future, errors
}
```

# That's it at the moment.
Feel free to add any comments, improvements, etc. They would be much appreciated.
