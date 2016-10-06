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


//
//    func testPerformanceExample() {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

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
}
