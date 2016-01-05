//
//  AddrInfo.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 24/12/2015.
//  Copyright © 2015 Andrew Thompson. All rights reserved.
//

import Darwin

/// Problem:    getaddrinfo() returns a linked list. It provides a method to free it
///             freeaddrinfo(). struct addrinfo contains a pointer to another 
///             struct, so memory must be managed for two structures.

/// Now, I figured that sockaddr isn't a good structure to hold the memory.
/// So I used sockaddr_storage since that is more compatible with other network
/// protocol uses.

public class AddrInfo : CustomDebugStringConvertible {
    public var addrinfo: Darwin.addrinfo
    public var sockaddr: UnsafeMutablePointer<Darwin.sockaddr> {
        get {
            return UnsafeMutablePointer(sockaddr_storage)
        }
    }
    public var sockaddr_storage: UnsafeMutablePointer<Darwin.sockaddr_storage>
    public var hostname: String? {
        if let hostname = String.fromCString(addrinfo.ai_canonname) {
            return hostname
        }
        do {
            if let hostname = try getnameinfo(self).hostname {
                return hostname
            }
        } catch {}
        return nil
    }
    @available(*, unavailable, renamed="hostname")
    public var canonname: String? {
        fatalError("unavailable function call")
    }
    public init() {
        addrinfo = Darwin.addrinfo()
        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>.alloc(
            sizeof(Darwin.sockaddr_storage)
        )
        addrinfo.ai_canonname = nil
        addrinfo.ai_addr = sockaddr
    }
    public init(claim addr: Darwin.addrinfo) {
        addrinfo = addr
        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>(addr.ai_addr)
    }
    public init(copy addr: Darwin.addrinfo) {
        addrinfo = addr
        sockaddr_storage = UnsafeMutablePointer.alloc(
            sizeof(Darwin.sockaddr_storage)
        )
        if addr.ai_addr != nil {
            sockaddr_storage.memory = UnsafeMutablePointer(addr.ai_addr).memory
        }
        addrinfo.ai_addr = sockaddr
        if addr.ai_canonname != nil {
            let length = Int(strlen(addr.ai_canonname) + 1)
            addrinfo.ai_canonname = UnsafeMutablePointer<Int8>.alloc(length)
            strcpy(addrinfo.ai_canonname, addr.ai_canonname)
        }
    }
    deinit {
        sockaddr_storage.dealloc(sizeof(Darwin.sockaddr_storage))
        if addrinfo.ai_canonname != nil {
            let length = Int(strlen(addrinfo.ai_canonname) + 1)
            addrinfo.ai_canonname.dealloc(length)
        }
    }
    
    public var debugDescription: String {
        var out = ""
        print(addrinfo, sockaddr_storage.memory, separator: ", ", terminator: "", toStream: &out)
        return out
    }

    public func setPort(port: Int32) throws {
            switch addrinfo.ai_family {
            case PF_INET:
                let ipv4 = UnsafeMutablePointer<sockaddr_in>(addrinfo.ai_addr)
                ipv4.memory.sin_port = htons(CUnsignedShort(port))
            case PF_INET6:
                let ipv6 = UnsafeMutablePointer<sockaddr_in>(addrinfo.ai_addr)
                ipv6.memory.sin_port = htons(CUnsignedShort(port))
            default:
                throw SocketError.ParameterError("Trying to set a port on a"
                    + " structure which does not use ports.")
            }
    }
}