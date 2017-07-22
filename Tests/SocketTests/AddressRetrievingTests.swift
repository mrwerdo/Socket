//
//  AddressRetrivingTests.swift
//  Socket
//
//  Created by Andrew Thompson on 7/10/16.
//
//

import XCTest
@testable import Socket

class AddressRetrivingTests: XCTestCase {
    
    func reason(with error: Error) -> String {
        return "An unexpected error occured: \(error)"
    }
    
    // Hmmm, this is really the only guarenteed address that we can expect on
    // every machine. I wonder what other methods there are to test getaddrinfo
    // with.
    
    func testGetLocalhostAddress() {
        do {
            let reason = "getaddrinfo could not find any loopback addresses, are you sure your system is configured correctly?"
            let addresses = try getaddrinfo(host: "localhost", service: nil, hints: addrinfo())
            XCTAssert(addresses.count > 0, reason)
        } catch {
            XCTFail(reason(with: error))
        }
    }
    
    func testGetHostName() {
        do {
            if try gethostname() == nil {
                XCTFail("Hostname was nil")
            }
        } catch {
            XCTFail(reason(with: error))
        }
    }

    func testGetInterfaceAddress() {
        if let interfaces = getifaddrs() {
            XCTAssert(interfaces.count > 0)
        } else {
            XCTFail("getifaddrs failed to return any values")
        }
    }
    
    func testGetHostByName() {
        do {
            if let host = try? gethostname(), let h = host {
                let _ = try gethostbyname(h, family: .inet)
            }
        } catch {
            XCTFail(reason(with: error))
        }
    }
    
    func testGetNameInfo() {
        let sockaddr = IPv4Address(address: 0, port: 5000)
        let addr = AddressInfo(family: .inet, type: .stream, protocol: .tcp, address: sockaddr)
        do {
            let k = try getnameinfo(addr)
            if k.hostname == nil && k.servicename == nil {
                XCTFail("getnameinfo could not find any hosts for localhost!")
            }
        } catch {
            XCTFail(reason(with: error))
        }
    }
}
