//
//  NetworkUtilitiesTests.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 12/12/2015.
//  Copyright © 2015 Andrew Thompson. All rights reserved.
//

import Foundation

/// How to use getaddrinfo(host:server:hints)
func testgetaddrinfo() {
    var hints = addrinfo(ai_flags: 0, ai_family: PF_INET, ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
    
    do {
        let addresses = try getaddrinfo(host: "andrews-imac.local", service: nil, hints: &hints)
        print(addresses)
    } catch let error as NetworkUtilitiesError {
        switch error {
        case .GetAddressInfoFailed(let num):
            print(String.fromCString(gai_strerror(num)))
        case .ParameterError(let str):
            print(str)
        default:
            break
        }
    } catch { } // no other errors are thrown
}

/// How to use gethostname() & sethostname(hostname:)
func testgetandsethostname() {
    do {
        
        let hostname = try gethostname()
        let newhostname = "mrwerdo.local"
        try sethostname(newhostname)
        let changedhostname = try gethostname()
        try sethostname(hostname!)
        let finalhostname = try gethostname()
        
        print(hostname, newhostname, changedhostname, finalhostname)
    } catch let e as NetworkUtilitiesError {
        switch e {
        case .GetAddressInfoFailed(let n):
            print("Probally not enough memory: \(String.fromCString(strerror(n)))")
        case .SetHostnameFailed(let n):
            print("Probally not root: \(String.fromCString(strerror(n)))")
        case .ParameterError(let d):
            print(d)
        default:
            break
        } 
    } catch { }
}

/// An example of using gethostname() and getaddrinfo(hostname:servname:hints)
func exampleUsingGetHostNameAndGetAddrInfo() {
    do {
        if let hostname = try gethostname() {
            var hints = addrinfo(ai_flags: 0, ai_family: PF_INET, ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
            let addrs = try getaddrinfo(host: hostname, service: nil, hints: &hints)
            for a in addrs {
                print("A possible address to \(hostname) is \(a)")
            }
        }
    } catch let e as NetworkUtilitiesError {
        switch e {
        case .ParameterError(let d):
            print(d)
        case .GetHostNameFailed(let n):
            print("Error retriving the host name: \(String.fromCString(strerror(n)))")
        case .GetAddressInfoFailed(let n):
            print("Error retriving the host address: \(String.fromCString(strerror(n)))")
        default:
            break
        }
    } catch {}
}

func testTCPConnect() {
    let data = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    
    do {
        let socket = try Socket(domain: DomainAddressFamily.INET, type: SocketType.Stream, proto: CommunicationProtocol.TCP)
        try socket.connect(to: "andrews-imac.local", port: 5000)
        try socket.send(data, length: data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), flags: 0)
        try socket.close()
    } catch let e as SocketError {
        switch e {
        case .NoAddressesFound(let reason, let errors):
            print(reason, ". Reason(s): ", separator: "", terminator: "")
            errors.forEach {
                print(String.fromCString(strerror($0))!, separator: ", ", terminator: "")
            }
            print("")
        default:
            print(e)
        }
    } catch let e as NetworkUtilitiesError {
        print(e)
    } catch {}
}


func testTCPServer() {
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
        case .GetAddressInfoFailed(let n):
            print("Get address info failed: \(String.fromCError(n))")
        case .ParameterError(let str):
            print("Parameter error: \(str)")
        default:
            print("Unknown error: \(e)")
        }
    } catch let e {
       print("Unknown error: \(e)")
    }
}


func testGetAddrInfoNoMemoryLeaks() {
    // I believe the only way to actually know if there is any memory leaks is 
    // to run it a million times!
    do {
        for _ in 0..<1_000_000 {
            do {
                var hints = addrinfo(ai_flags: AI_CANONNAME, ai_family: 0, ai_socktype: 0, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
                let _ = try getaddrinfo(host: "andrews-imac.local", service: nil, hints: &hints)
            } catch let e as NetworkUtilitiesError {
                switch e {
                case .GetAddressInfoFailed(let n):
                    print(String.fromCError(n))
                default:
                    print(e)
                }
            }
        }
    } catch {}
}

func testTCPLocalSocket() {
    do {
        let socket = try Socket(domain: DomainAddressFamily.Local, type: SocketType.Stream, proto: .Other(0))
        try socket.bind(toFile: "/tmp/mytcpsocket")
        try socket.listen(5)
        while true {
            let incomming = try socket.accept()
            print("Recieving new message...: ", terminator: "")
            if let message = try incomming.recv(1024) {
                if let str = String.fromCString(UnsafePointer(message.data)) {
                    print("\(str)")
                } else {
                    print("failed to read data")
                }
            } else {
                print("failed to recieve data")
            }
            try incomming.close()
        }
    } catch let e as SocketError {
        switch e {
        case .CreationFailed(let n):
            print("socket failed: \(String.fromCError(n))")
        case .UnlinkFailed(let n):
            print("unlink failed: \(String.fromCError(n))")
        default:
            print(e)
        }
    } catch {}
}

func testUDPSendTo() {
    do {
        let data = "Hello, World!"
        let socket = try Socket(domain: DomainAddressFamily.INET, type: SocketType.Datagram, proto: CommunicationProtocol.UDP)
        for address in try getaddrinfo(host: "localhost", service: nil, hints: &socket.address.addrinfo) {
            try address.setPort(5000)
            try socket.send(to: address, data: data, length: data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        }
    } catch let e as SocketError {
        switch e {
        case .SendToFailed(let n):
            print("Send to failed: \(String.fromCError(n))")
        default:
            print(e)
        }
    } catch {}
}

func testUDPRecv() {
    do {
        let socket = try Socket(domain: DomainAddressFamily.INET, type: SocketType.Datagram, proto: CommunicationProtocol.UDP)
        try socket.bind(toAddress: "localhost", port: 5000)
        
        while true {
            if let message = try socket.recv(1024) {
                if let str = String.fromCString(UnsafePointer(message.data)) {
                    print("New message: \(str)")
                } else {
                    print("Error displaying message")
                }
            } else {
                print("Error recieving message")
            }
        }
        
    } catch let e as SocketError {
        switch e {
        case .CreationFailed(let n):
            print("Error creating socket \(String.fromCError(n))")
        case .NoAddressesFound(let str, let n):
            print("Could not find an address: \(str)")
            n.forEach { print(String.fromCError($0), terminator: ", ") }
            print("")
        default:
            print(e)
        }
    } catch {}
}

func testGetnameInfo() {
    do {
        let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
        let address = try getaddrinfo(host: "15M216063.local", service: nil, hints: &socket.address.addrinfo)
        try socket.connect(to: address.first! , port: 5000)
        try socket.send("Hello, World!")
        if let peer = socket.peerAddress {
            print(peer.hostname)
        } else {
            print("failed to get peer address")
        }
        try socket.close()
    } catch let e as SocketError {
        switch e {
        case .ConnectFailed(let n):
            print(String.fromCError(n))
        default:
            print(e)
        }
    } catch let e as NetworkUtilitiesError {
        switch e {
        case .GetNameInfoFailed(let n):
            print(String.fromCString(gai_strerror(n)))
        default:
            print(e)
        }
    } catch {
        print(error)
    }
}

func testMoreTCPServerStuff() {
    do {
        let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
        try socket.bind(toAddress: "andrews-imac.local", port: 5000)
        if let hostname = socket.address.hostname {
            print("Bound server to \(hostname) on port 5000...")
        }
        try socket.listen(5)
        while true {
            let incomming = try socket.accept()
            if let message = try incomming.recv(1024) {
                if let data = String.fromCString(UnsafeMutablePointer(message.data)) {
                    print("Recieved a message from \(incomming.address.hostname ?? "an unknown host"): \(data)")
                } else {
                    print("Failed to decode data.")
                }
            } else {
                print("Failed to recieve data.")
            }
            try incomming.send("Hello, your address is: \(incomming.address.hostname ?? "unknown")")
            try incomming.close()
        }
    } catch {
        print(error)
    }
}