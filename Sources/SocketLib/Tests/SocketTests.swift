//
//  SocketTests.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 8/01/2016.
//  Copyright © 2016 Andrew Thompson. All rights reserved.
//

// import Socket
import Darwin


let shouldPrint = true
let shouldCrash = true
let shouldPrintFunctionTags = true

func msg(str: String, terminator: String = "\n") {
    if shouldPrint {
        print(str, terminator: terminator)
    }
}
func diemsg(error: ErrorType) {
    if shouldCrash {
        fatalError("\(error)")
    }
}
func dieWhenFalse(value: Bool, _ message: String = "") {
    if shouldCrash {
        assert(value, message)
    }
}
func pretag(function: StaticString = __FUNCTION__) {
    if shouldPrintFunctionTags {
        print("\(function)... ", terminator: "") // then pretag
    }
}
func endtag(function: StaticString = __FUNCTION__) {
    if shouldPrintFunctionTags {
        print("done")
    }
}

/// - parameter domain:     Either `INET` or `INET6`, not `Local`
/// - parameter hostname:   A host name to bind to, typically the loopback
///                         address. `"localhost"` for `INET`, `"::1"` for
///                         `INET6`
func testThatItStillWorksForInsaneUsers(
    domain: DomainAddressFamily,
    _ hostname: String
    ) {
        pretag()
        
        do {
            for i in 1...1_024 {
                let socket = try Socket(
                    domain: domain,
                    type: .Stream,
                    proto: .TCP
                )
                try socket.setShouldReuseAddress(true)
                try socket.bindTo(host: hostname, port: 5000)
                try socket.listen(1)
                
                let client = try Socket(
                    domain: domain,
                    type: .Stream,
                    proto: .TCP
                )
                try client.connectTo(host: hostname, port: 5000)
                
                let peer = try socket.accept()
                let data = "hello, world! I'm in the loop at: \(i)"
                try client.send(data)
                
                if  let m = try peer.recv(1024),
                    let message = String.fromCString(UnsafePointer(m.data)) {
                        dieWhenFalse(
                            data == message,
                            "data recieved does not matched data sent"
                        )
                }
                try peer.close()
                try client.close()
                
                try socket.close()
            }
        } catch {
            diemsg(error)
        }
        endtag()
}

func testSendingLotsOfDataAndMakingSureItIsStillTheSame(
    domain: DomainAddressFamily,
    _ hostname: String
    ) {
        pretag()
        
        let payloadLength = 1024
        let payloadSize = payloadLength * sizeof(UInt64)
        
        // How much data does this actually send?
        //
        // In each loop, 1024 * 64 bits == 8192 bytes, being sent.
        // In total, 1024 * 1024 * 8 bytes == 8 MiB, being sent (which is roughly
        // equal to 8 MB being sent).
        
        
        do {
            for _ in 1...1_024 {
                let socket = try Socket(
                    domain: domain,
                    type: .Stream,
                    proto: .TCP
                )
                try socket.setShouldReuseAddress(true)
                try socket.bindTo(host: hostname, port: 5000)
                try socket.listen(1)
                
                let client = try Socket(
                    domain: domain,
                    type: .Stream,
                    proto: .TCP
                )
                try client.connectTo(host: hostname, port: 5000)
                
                let peer = try socket.accept()
                
                // Generate payload
                
                var payload = [UInt64](count: payloadLength, repeatedValue: 0)
                for i in 0..<payloadLength {
                    payload[Int(i)] = UInt64(i)
                }
                
                try client.send(&payload, length: payloadSize)
                
                // Remark:  Although TCP is reliable, the system may not process
                //          all the data it is given in a single call to send
                //          or recv. As such, the amount of data recieved may
                //          vary. To avoid this, you should call recieve
                //          multiple times until enough data has been collected
                //          to construct a message.
                
                if  let m = try peer.recv(Int(payloadSize)) {
                    let recievedBuffer = UnsafePointer<UInt64>(m.data)
                    
                    // payload is an array of UInt64's, so a Int8 containing the
                    // same bitwise contents will be payloadLength *
                    /// sizeof(UInt64)
                    //
                    // Socket.Message.length is measured in bytes - so it works
                    // in with Int8. payload is measured in UInt64's, so we must
                    // adjust the way we examine the data
                    
                    // Remove excess bytes from the data recieved
                    let remainder = m.length % 8
                    let amountOfDataRecieved = (m.length - remainder) / 8
                    
                    for i in 0..<amountOfDataRecieved {
                        dieWhenFalse(
                            recievedBuffer[i] == payload[i],
                            "data sent is not equal to data recieved"
                        )
                    }
                }
                
                try peer.close()
                try client.close()
                try socket.close()
                
            }
        } catch {
            diemsg(error)
        }
        endtag()
}

func testGettingPeoplesAddresses() {
    pretag()
    do {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: PF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        let hostname = try gethostname()
        let addresses = try getaddrinfo(
            host: hostname,
            service: nil,
            hints: &hints
        )
        
        dieWhenFalse(
            addresses.count != 0,
            "You have no internet address - how did you download this code?"
        )
        
    } catch {
        diemsg(error)
    }
    endtag()
}

func testChangingPeoplesComputerNames() {
    pretag()
    do {
        let originalHostname = try gethostname()
        let newhostname = "sowhydontyouexchangeyourbits"
            + "andillexchangemineandwellseewhathappens.local"
        try sethostname(newhostname)
        let changedhostname = try gethostname()
        dieWhenFalse(newhostname == changedhostname)
        try sethostname(originalHostname!)
        let finalHostname = try gethostname()
        dieWhenFalse(
            originalHostname! == finalHostname!,
            "hostname wasn't restored properly! Everyone's gonna die! 😱"
        )
    } catch NetworkUtilitiesError.SetHostnameFailed(let n) {
        if n == EPERM {
            msg("You must be root to set the hostname")
            return
        } else {
            diemsg(NetworkUtilitiesError.SetHostnameFailed(n))
        }
    } catch {
        diemsg(error)
    }
    endtag()
}

func testUnixSockets() {
    pretag()
    do {
        for _ in 1...1024 {
            let lhs = try Socket(domain: .Local, type: .Stream, proto: .Other(0))
            try lhs.bindTo(file: "/tmp/swiftsockets-testUnixSockets")
            try lhs.listen(1)
            
            let rhs = try Socket(domain: .Local, type: .Stream, proto: .Other(0))
            try rhs.connectTo(file: "/tmp/swiftsockets-testUnixSockets")
            
            let peer = try lhs.accept()
            let payload = "Hello, World!"
            try peer.send(payload)
            if  let m = try rhs.recv(1024),
                let data = String.fromCString(UnsafePointer(m.data)) {
                    dieWhenFalse(
                        data == payload,
                        "data sent is not equal to data recieved!"
                    )
            }
            
            try lhs.close()
            try rhs.close()
            try peer.close()
            
        }
    } catch {
        diemsg(error)
    }
    endtag()
}

func testGetAddrInfoForGettingAHostName() {
    pretag()
    do {
        var hints = addrinfo()
        hints.ai_flags = AI_CANONNAME
        let hosts = try getaddrinfo(host: "localhost", service: nil, hints: &hints)
        for host in hosts {
            dieWhenFalse(host.hostname != "", "no host name resolved!")
        }
    } catch {
        diemsg(error)
    }
    endtag()
}