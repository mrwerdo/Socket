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
try socket.connect(toAddress: "hostname", port: 5000)
try socket.send(data, length: data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), flags: 0)
try socket.close()
```

To create and send data over a UDP socket, do:
```
let data = "Hello, UDP!"
let socket = try Socket(domain: .INET, type: .Datagram, proto: .UDP)
for address in try getaddrinfo(host: "hostname", service: nil, hints: &socket.address.addrinfo) {
  // Choose your address here. You may not want to send to every address matching the address and hostname.
  try address.setPort(5000)
  try socket.send(to: address, data: data, length: data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
}
try socket.close()
```

Recieving data is just as simple...

For a TCP socket, do:
```
let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
try socket.connect(toAddress: "hostname", port: 5000)
if let message = try socket.recv(1024) {
  if let decoded_str = String.fromCString(UnsafePointer(message.data)) {
    print("Obtained new message: \(decoded_str)")
  } else {
    print("Error decoding message!")
  }
} else {
  print("Connection closed.")
}
try socket.close()
```

For a UDP socket, do:
```
let socket = try Socket(domain: .INET, type: .Datagram, proto: .UDP)
try socket.bind(toAddress: "hostname", port: 5000)
if let message = try socket.recv(1024) {
  if let str = String.fromCString(UnsafePointer(message.data)) {
    print("Obtained new message: \(str)")
  } else {
    print("Error decoding message!")
  }
} // will never get here, UDP is connectionless
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
  var shouldStop = false
    
  let socket = try Socket(domain: DomainAddressFamily.INET, type: SocketType.Stream, proto: CommunicationProtocol.TCP)
  try socket.bind(toAddress: "localhost", port: 5000)
  try socket.listen(5)
  while !shouldStop {
    let incoming = try socket.accept()
    if let message = try incoming.recv(1024) {
      if let str = String.fromCString(UnsafePointer<Int8>(message.data)) {
        if str == "stop" {
          shouldStop = true
        } else {
          print("New message: \(str)")
        }
      } else {
        print("Error recieving data.")
      }
    }
    try incoming.close()
  }
  print("done")
  try socket.close()
} catch let e as SocketError {
  switch e {
  case .BindFailed(let n):
    print("Bind failed: \(String.fromCError(n))")
  case .ListenFailed(let n):
    print("Listen failed: \(String.fromCError(n))")
  case .AcceptFailed(let n):
    print("Accept failed: \(String.fromCError(n))")
  case .RecvFromFailed(let n):
    print("Recv failed: \(String.fromCError(n))")
  case .RecvTryAgain:
    print("This should really be handled in the recieve code above.")
  case .CloseFailed(let n):
    print("Close failed: \(String.fromCError(n))")
  case .ParameterError(let str):
    print("Parameter error: \(str)")
  case .NoAddressesFound(let reason, let errors):
    print("No addresses found: \(reason)")
    print("Reasons: ", terminator: "")
    errors.forEach { print(String.fromCError($0), terminator: ", ") }
    print("")
  default:
    print("Unknown error: \(e)")
  }
} catch let e as NetworkUtilitiesError {
  switch e {
  case .GetAddressFailed(let n):
    print("Get address info failed: \(String.fromCError(n))")
  case .ParameterError(let str):
    print("Parameter error: \(str)")
  default:
    print("Unknown error: \(e)")
  }
} catch let e {
  print("Unknown error: \(e)")
}
```

# That's it at the moment.
Feel free to add any comments, improvements, etc. They would be much appreciated.
