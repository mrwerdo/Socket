# Sockets for Swift!
A low level socket library written in swift for beaming data across the internet!

# Description
Swift-Sockets is a socket wrapper for the BSD C socket layer. It provides convenient access to the socket layer, allowing various types of connections to be created. Swift-Sockets also embraces Swift's new error model, allowing for advanced error handling while still maintaining easy to read code.

# What can you do?

Send data accross the internet. Seriously.

The library is a wrapper for the C API, so it's use is prety versatile. Typical
use for sockets is to send information over a reliable connection formed using 
`TCP/IP`, or `TCP/IPv6`. In addition user datagram sockets and local sockets
are supported too. 

It is possible to use other family types, socket types, and protocols - however
the use of other protocols is pretty uncommon, as far as I can tell scouring the
internet. Raw sockets can be used, however I have found that on a mac, they are
pretty limited without doing any extra work (i.e. lots of platform specific 
code which uses fcntl's to configure the networking card just right).

Anyway, enough rambling...

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

And for a UDP socket, do:
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

Copy the source files located in `SocketLib` into your project - you don't need the Tests subdirectory however. The was support for the swift package manager, however I couldn't manage to get it to work (yet).

# Error Handling

Doing networking right means to handle every error possible in a clean and appropiate manner. Every function which will fail will through an error, which will allow the user of this library to implement their own error handling code. Functions which wrap around system calls that fail will an error number as an associate value. Check the inline documentation for a brief description of the errors, and refer to the manual pages for more information. Every function also includes inline documentation - including the errors thrown, so it is easy to know what errors are thrown and handle them appropiately.

Below is an example of a simple TCP server - Upon encountering an error, fail. I've tried to show as many errors as possible, to show what types of errors are possible.

**Note**: This implementation, although it does work, is not performing in an optimal way. It could be further improved by introducing the `select(2)` system call, or by using asynchronous operations (e.g. GCD).

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
    errmsg(error) // other, possible future, errors, which may be implemented
}
```

# TODOs
- Implement `select(2)` functionality
- Make casting platform independant (hard coded types are used currently)
- Implement non-blocking sockets (however, requires `c` code)
- Contiune implementing tests
- Learn how to do continuous integration
- Investegate linux compatability
- Do may math homework...
