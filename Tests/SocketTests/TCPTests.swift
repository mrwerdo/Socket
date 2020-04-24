//
//  TCPTests.swift
//  Socket
//
//  Created by Andrew Thompson on 5/10/16.
//
//

import XCTest
@testable import Socket

class TCPTestCase: XCTestCase {
    let port: in_port_t = 5000
    
    /// Client
    var c: Socket?
    /// Server
    var s: Socket?
    /// Extra Peers
    var p0: Socket?
    var p1: Socket?
    
    func reason(with error: Error) -> String {
        return "An error occured that should not have: \(error)"
    }
    
    override func tearDown() {
        c = nil
        s = nil
        p0 = nil
        p1 = nil
        super.tearDown()
    }
    
    func pair(host: String, port: in_port_t, matching filter: (AddressInfo) -> Bool) throws -> (Socket, Socket) {
        for address in try find(host: host, on: port) where filter(address) {
            do {
                let server = try Socket(info: address)
                try server.bind()
                try server.listen(1)
                let peer1 = try Socket(info: address)
                try peer1.connect()
                let peer2 = try server.accept()
                try server.close()
                return (peer1, peer2)
            } catch {
                continue
            }
        }
        // TODO: Make this a proper error.
        throw SocketError.parameter("Exhausted addresses to pair the sockets on.", .`init`)
    }
}

class TCPClientAndServer : TCPTestCase {
    func testBindAndConnect() {
        do {
            let addresses = try find(host: "localhost", on: port)
            for host in addresses where (host.family == DomainAddressFamily.inet) {
                do {
                    s = try Socket(info: host)
                    try s!.bind()
                    try s!.listen(5)
                    break
                } catch {
                    s = nil
                    continue
                }
            }
            
            for host in addresses where (host.family == DomainAddressFamily.inet && (host.communicationProtocol.systemValue == CommunicationProtocol.tcp.systemValue)) {
                do {
                    c = try Socket(info: host)
                    try c!.connect()
                    break
                } catch {
                    print(error)
                    c = nil
                    continue
                }
            }
            
            if let server = s, let client = c {
                p0 = try server.accept()
                let k = "Hello. Look at the amazing text I can send!"
                try p0!.send(k)
                if let message = try client.recv(1024) {
                    let str = String(cString: message.data)
                    XCTAssert(k == str)
                } else {
                    XCTFail("unable to send data")
                }
            } else {
                XCTFail("Unable to find any addresses to sent up sending on!")
            }
            
        } catch {
            XCTFail(reason(with: error))
        }
    }
    
    func testPairAddresses() {
        do {
            let (p0, p1) = try pair(host: "localhost", port: 5000) { (info: AddressInfo) -> Bool in
                switch info.communicationProtocol {
                case .tcp:
                    return true
                default:
                    return false
                }
            }
            
            let sentMessage = "Hello, World"
            try p0.send(sentMessage)
            if let data = try p1.recv(1024) {
                let str = String(cString: data.data)
                XCTAssert(str == sentMessage)
            } else {
                XCTFail("failed to recieve data from the sending pere.")
            }
            
        } catch {
            XCTFail(reason(with: error))
        }
    }
}
