//
//  SocketTests.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 8/01/2016.
//  Copyright © 2016 Andrew Thompson. All rights reserved.
//

// import Socket
import Darwin

/// IPv4, SOCK_STREAM, IPPROTO_TCP, port=5000
func testThatItStillWorksForInsaneUsers(domain: DomainAddressFamily, _ hostname: String) {
    let shouldPrint = true
    let shouldCrash = true
    for i in 1...1_000 {
        do {
            let socket = try Socket(domain: domain, type: .Stream, proto: .TCP)
            try socket.setShouldReuseAddress(true)
            try socket.bindTo(host: hostname, port: 5000)
            try socket.listen(1)
            
            let client = try Socket(domain: domain, type: .Stream, proto: .TCP)
            try client.connectTo(host: hostname, port: 5000)
            
            let peer = try socket.accept()
            let data = "hello, world! I'm in the loop at: \(i)"
            try client.send(data)
            
            if  let m = try peer.recv(1024),
                let message = String.fromCString(UnsafePointer(m.data)) {
                    if shouldPrint {
                        print("Got data: \(message)")
                    }
                    if shouldCrash {
                        assert(
                            data == message,
                            "data recieved does not matched data sent"
                        )
                    }
            }
            try peer.close()
            try client.close()
            
            try socket.close()
        } catch {
            if shouldCrash {
                fatalError("failed to continue loop at i=\(i): \(error)")
            }
        }
    }
    print("done")
}
