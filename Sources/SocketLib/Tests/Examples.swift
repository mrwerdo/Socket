//
//  Examples.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 10/01/2016.
//  Copyright © 2016 Andrew Thompson. All rights reserved.
//

import Foundation

// Coded examples for the readme file.

@noreturn func errmsg(_ error: ErrorProtocol) {
    fatalError("error performing \(#function); reason: \(error)")
}

func simpleTCPSend() {
    do {
        let data = "Hello, TCP!"
        let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
        try socket.send(str: data)
        try socket.close()
    } catch {
        errmsg(error)
    }
}

func simpleUDPSend() {
    do {
        let data = "Hello, UDP!"
        let destinationHost = "localhost"
        let socket = try Socket(domain: .INET, type: .Datagram, proto: .UDP)
        for address in try getaddrinfo(host: destinationHost, service: nil, hints: &socket.address.addrinfo) {
            do {
                let length = data.lengthOfBytes(using:)(using: NSUTF8StringEncoding)
                try address.setPort(port: 500)
                try socket.sendTo(address: address, data: data, length: length)
                break // only send once
            } catch {
                continue
            }
        }
        try socket.close()
    } catch {
        errmsg(error)
    }
}

func simpleTCPRecv() {
    do {
        let sendingHost = "localhost"
        let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
        try socket.connectTo(host: sendingHost, port: 5000)
        
        do {
            guard let message = try socket.recv(maxSize: 1024) else {
                return // connection closed
            }
            if let data = String(utf8String: UnsafePointer(message.data)) {
                print("New message \(message.length) bytes long: \(data)")
            } else {
                print("Error decoding message!")
            }
        } catch SocketError.RecvTryAgain {
            // non-fatal error, try again some time since no data available
        }
        try socket.close()
    } catch {
        errmsg(error)
    }
}

func simpleUDPRecv() {
    do {
        let recievingHost = "localhost"
        let socket = try Socket(domain: .INET, type: .Stream, proto: .UDP)
        try socket.bindTo(host: recievingHost, port: 5000)
        
        do {
            let message = try socket.recv(maxSize: 1024)! // UDP is connectionless
            if let data = String(utf8String: UnsafePointer(message.data)) {
                print("New message \(message.length) bytes long: \(data)")
            } else {
                print("Error decoding message!")
            }
        } catch SocketError.RecvTryAgain {
            // non-fatal error, try again some time since no data available
        }
        try socket.close()
    } catch {
        errmsg(error)
    }
}
func simpleTCPServer() {
    do {
        let recievingHost = "localhost"
        var shouldRun = true
        
        let socket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
        try socket.setShouldReuseAddress(true)
        try socket.bindTo(host: recievingHost, port: 5000)
        try socket.listen(backlog: 5)
        
        mainLoop: while shouldRun {
            let client = try socket.accept()
            
            recvLoop: while true {
                do {
                    guard let message = try client.recv(maxSize: 1024) else {
                        try client.close()
                        break recvLoop
                    }
                    if let data = String(utf8String: UnsafePointer(message.data)) {
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
            try client.send(str: "Goodbye!")
            try client.close()
        }
        try socket.close()
        
    } catch let e as SocketError {
        func emsg(_ n: Int32) -> String {
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
        errmsg(error)
    }
}