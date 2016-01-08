//
//  SocketTests.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 8/01/2016.
//  Copyright © 2016 Andrew Thompson. All rights reserved.
//

import XCTest
import Foundation

class TestSocket_Connect: XCTestCase {
    
    let testing_port: Int32 = 5000
    var serverSocket: Socket!
    var serverActiveClient: Socket!
    
    override func setUp() {
        do {
            serverSocket = try Socket(domain: .INET, type: .Stream, proto: .TCP)
            try serverSocket.setShouldReuseAddress(true)
            try serverSocket.bind(toAddress: "localhost", port: testing_port)
            try serverSocket.listen(1)
        } catch {
            XCTFail("Could not create server: \(error)")
        }
    }
    
    func accept() throws {
        serverActiveClient = try serverSocket.accept()
    }
    func recv(size: Int, handler: (m: Socket.Message?) -> ()) throws {
        let m = try serverActiveClient.recv(size)
        handler(m: m)
    }
    func close() throws {
        try serverActiveClient.close()
        serverActiveClient = nil
    }
    
    override func tearDown() {
        do {
            try serverSocket.close()
        } catch {
            XCTFail("Could not close socket: \(error)")
        }
    }
    
    func testConnect() {
        
        //Random data
        let data = "this is a very long string! asnotehuasnoehuanotehuasnoethu"
        + "sanotehuansoethuanethuasontehusnaotehunotheuasonthnthibainhlcg'd,.u"
        + "138lrgc,.yn'htidevambwkbw-b./y798asnotehus1nt3h59028CNTHS:EMQS˜ˇÓSN"
        + "5612    95-+6'., 3i2aeoqk'h3c0'',lgaid''"
        
        do {
            let client = try Socket(domain: .INET, type: .Stream, proto: .TCP)
            try client.connect(to: "localhost", port: testing_port)
            
            try accept()
            
            try client.send(data)
            
            try recv(data.lengthOfBytesUsingEncoding(NSUTF8StringEncoding), handler: { (m) -> () in
                if let message = m {
                    if let str = String.fromCString(UnsafePointer(message.data)) {
                        if str != data {
                            print("String is: \(str)")
                            print("Data is: \(data)")
                            XCTFail("(str != data)!")
                        }
                        return
                    }
                }
                XCTFail("recv failed: could not decode data")
            })
            try close()
            try client.close()
        } catch {
            XCTFail("client failde to run: \(error)")
        }
        
    }
    
}