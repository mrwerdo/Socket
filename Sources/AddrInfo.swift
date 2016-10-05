//
//  AddrInfo.swift
//  QuickShare
//
//  Copyright (c) 2016 Andrew Thompson
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Darwin

//// Problem:    getaddrinfo() returns a linked list. It provides a method to free it
////             freeaddrinfo(). struct addrinfo contains a pointer to another
////             struct, so memory must be managed for two structures.
//
//// Now, I figured that sockaddr isn't a good structure to hold the memory.
//// So I used sockaddr_storage since that is more compatible with other network
//// protocol uses.
//
///// AddrInfo contains a references to address structures and socket address 
///// structures.
//@available(*, deprecated: 10.10)
//public class AddrInfo : CustomDebugStringConvertible {
//    public var addrinfo: Darwin.addrinfo
//    public var sockaddr: UnsafeMutablePointer<Darwin.sockaddr> {
//        get {
//            
//            
//            return UnsafeMutablePointer(sockaddr_storage)
//        }
//    }
//    public var sockaddr_storage: UnsafeMutablePointer<Darwin.sockaddr_storage>
//    public var hostname: String? {
//        if let hostname = String(validatingUTF8: addrinfo.ai_canonname) {
//            return hostname
//        }
//        //        if let hostname = try? getnameinfo(self).hostname {
//        //    return hostname
//        //}
//        return nil
//    }
//    
//    public var sockaddr_in: UnsafeMutablePointer<Darwin.sockaddr_in> {
//        return UnsafeMutablePointer<Darwin.sockaddr_in>(self.sockaddr)
//    }
//    
//    /// Constructs the addresses so they all reference each other internally.
//    public init() {
//        addrinfo = Darwin.addrinfo()
//        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>.allocate(
//            capacity: sizeof(Darwin.sockaddr_storage)
//        )
//        
//        addrinfo.ai_canonname = nil
//        addrinfo.ai_addr = sockaddr
//    }
//    /// Claims ownership of the address provided. It must have been created 
//    /// by performing: 
//    ///
//    ///      let size = sizeof(sockaddr_storage)
//    ///      let addr = UnsafeMutablePointer<sockaddr_storage>.alloc(size)
//    public init(claim addr: Darwin.addrinfo) {
//        addrinfo = addr
//        sockaddr_storage = UnsafeMutablePointer<Darwin.sockaddr_storage>(
//            addr.ai_addr
//        )
//    }
//    public init(copy addr: Darwin.addrinfo) {
//        addrinfo = addr
//        sockaddr_storage = UnsafeMutablePointer.allocate(capacity: sizeof(Darwin.sockaddr_storage))
//        if addr.ai_addr != nil {
//            sockaddr_storage.pointee = UnsafeMutablePointer(addr.ai_addr).pointee
//        }
//        addrinfo.ai_addr = sockaddr
//        if addr.ai_canonname != nil {
//            let length = Int(strlen(addr.ai_canonname) + 1)
//            addrinfo.ai_canonname = UnsafeMutablePointer<Int8>.allocate(capacity: length)
//            strcpy(addrinfo.ai_canonname, addr.ai_canonname)
//        }
//    }
//    deinit {
//        sockaddr_storage.deallocate(capacity: sizeof(Darwin.sockaddr_storage))
//        if addrinfo.ai_canonname != nil {
//            let length = Int(strlen(addrinfo.ai_canonname) + 1)
//            addrinfo.ai_canonname.deallocate(capacity: length)
//        }
//    }
//    
//    public var debugDescription: String {
//        var out = ""
//        let sockAddrStorage = sockaddr_storage.pointee
//        print(addrinfo,
//            sockAddrStorage,
//            separator: ", ",
//            terminator: "",
//            to: &out
//        )
//        return out
//    }
//
//    public func setPort(_ port: Int32) throws {
//        typealias address = Darwin.sockaddr_in
//        switch addrinfo.ai_family {
//        case PF_INET:
//            let ipv4 = UnsafeMutablePointer<address>(addrinfo.ai_addr)
//            ipv4?.pointee.sin_port = htons(CUnsignedShort(port))
//        case PF_INET6:
//            let ipv6 = UnsafeMutablePointer<address>(addrinfo.ai_addr)
//            ipv6?.pointee.sin_port = htons(CUnsignedShort(port))
//        default:
//            throw SocketError.parameter("do not know how to set port", .setOption)
//        }
//    }
//}
