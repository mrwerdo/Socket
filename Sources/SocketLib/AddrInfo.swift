//
//  AddrInfo.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 24/12/2015.
//  Copyright © 2015 Andrew Thompson. All rights reserved.
//

import Darwin

// Problem:    getaddrinfo() returns a linked list. It provides a method to free it
//             freeaddrinfo(). struct addrinfo contains a pointer to another
//             struct, so memory must be managed for two structures.

// Now, I figured that sockaddr isn't a good structure to hold the memory.
// So I used sockaddr_storage since that is more compatible with other network
// protocol uses.

/// AddrInfo contains a references to address structures and socket address 
/// structures.
public class AddrInfo : CustomDebugStringConvertible {
    public var addrinfo: Darwin.addrinfo
    public var sockaddr: UnsafeMutablePointer<Darwin.sockaddr> {
        get {
            return UnsafeMutablePointer(sockaddr_storage)
        }
    }
    public var sockaddr_storage: UnsafeMutablePointer<Darwin.sockaddr_storage>
    public var hostname: String? {
        if let hostname = String(utf8String: addrinfo.ai_canonname) {
            return hostname
        }
        if let hostname = try? getnameinfo(address: self).hostname {
            return hostname
        }
        return nil
    }
    @available(*, unavailable, renamed:"hostname")
    public var canonname: String? {
        fatalError("unavailable function call")
    }
    /// Constructs the addresses so they all reference each other internally.
    public init() {
        addrinfo = Darwin.addrinfo()
        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>(
            allocatingCapacity: sizeof(Darwin.sockaddr_storage)
        )
        addrinfo.ai_canonname = nil
        addrinfo.ai_addr = sockaddr
    }
    /// Claims ownership of the address provided. It must have been created 
    /// by performing: 
    ///
    ///      let size = sizeof(sockaddr_storage)
    ///      let addr = UnsafeMutablePointer<sockaddr_storage>.alloc(size)
    public init(claim addr: Darwin.addrinfo) {
        addrinfo = addr
        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>(
            addr.ai_addr
        )
    }
    public init(copy addr: Darwin.addrinfo) {
        addrinfo = addr
        sockaddr_storage = UnsafeMutablePointer(
            allocatingCapacity: sizeof(Darwin.sockaddr_storage)
        )
        if addr.ai_addr != nil {
            sockaddr_storage.pointee = UnsafeMutablePointer(addr.ai_addr).pointee
        }
        addrinfo.ai_addr = sockaddr
        if addr.ai_canonname != nil {
            let length = Int(strlen(addr.ai_canonname) + 1)
            addrinfo.ai_canonname = UnsafeMutablePointer<Int8>(allocatingCapacity: length)
            strcpy(addrinfo.ai_canonname, addr.ai_canonname)
        }
    }
    deinit {
        sockaddr_storage.deallocateCapacity(sizeof(Darwin.sockaddr_storage))
        if addrinfo.ai_canonname != nil {
            let length = Int(strlen(addrinfo.ai_canonname) + 1)
            addrinfo.ai_canonname.deallocateCapacity(length)
        }
    }
    
    public var debugDescription: String {
        var out = ""
        let sockAddrStorage = sockaddr_storage.pointee
        print(addrinfo,
            sockAddrStorage,
            separator: ", ",
            terminator: "",
            to: &out
        )
        return out
    }

    public func setPort(port: Int32) throws {
            switch addrinfo.ai_family {
            case PF_INET:
                let ipv4 = UnsafeMutablePointer<sockaddr_in>(addrinfo.ai_addr)
                ipv4.pointee.sin_port = htons(value: CUnsignedShort(port))
            case PF_INET6:
                let ipv6 = UnsafeMutablePointer<sockaddr_in>(addrinfo.ai_addr)
                ipv6.pointee.sin_port = htons(value: CUnsignedShort(port))
            default:
                throw SocketError.ParameterError("Trying to set a port on a"
                    + " structure which does not use ports.")
            }
    }
}