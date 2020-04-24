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
import Foundation

struct CSocket {
    
    enum SError : Error {
        case bind(CInt)
        case connect(CInt)
        case send(CInt)
        case recv(CInt)
    }
    
    static func bind(fd: CInt, to sa: sockaddr_storage) throws {
        var l = sa
        try withUnsafePointer(to: &l) { saptr in
            let type = sockaddr.self
            let c = MemoryLayout<sockaddr>.size
            try saptr.withMemoryRebound(to: type, capacity: c) { ptr in
                guard 0 == Darwin.bind(fd, ptr, socklen_t(sa.ss_len)) else {
                    throw SError.bind(errno)
                }
            }
        }
    }
    
    static func connect(fd: CInt, to sa: sockaddr_storage) throws {
        var l = sa
        try withUnsafePointer(to: &l) { saptr in
            let type = sockaddr.self
            let c = MemoryLayout<sockaddr>.size
            try saptr.withMemoryRebound(to: type, capacity: c) { ptr in
                guard 0 == Darwin.connect(fd, ptr, socklen_t(sa.ss_len)) else {
                    throw SError.connect(errno)
                }
            }
        }
    }
    
    static func send(fd: CInt,
                     to sa: sockaddr_storage,
                     data: Data,
                     flags: CInt = 0,
                     packetSize: Int = 1024,
                     numberOfAttempts loopCount: Int = 1) throws -> Int {
        
        var l = sa
        guard data.count > 0 else {
            return 0
        }
        
        return try data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
            return try withUnsafePointer(to: &l) { saptr -> Int in
                let type = sockaddr.self
                let c = MemoryLayout<sockaddr>.size
                return try saptr.withMemoryRebound(to: type, capacity: c) { addressptr -> Int in
                    
                    guard var head = ptr.baseAddress else {
                        return 0
                    }
                    
                    var bytesLeft = data.count
                    var bytesSent = 0
                    
                    for _ in 0..<loopCount where data.count > bytesSent {
                        let len = min(bytesLeft, packetSize)
                        let ret = Darwin.sendto(fd,
                                                head,
                                                len,
                                                flags,
                                                addressptr,
                                                socklen_t(sa.ss_len))
                        
                        guard ret != -1 else {
                            throw SError.send(errno)
                        }
                        
                        bytesSent += ret
                        bytesLeft -= ret
                        head = head.advanced(by: ret)
                    }
                    return bytesSent
                }
            }
        }
    }
    
//    static func recv(fd: CInt, size: Int, flags: CInt = 0) throws -> (length: Int, ptr: UnsafeRawPointer) {
//        var buffer = UnsafeMutablePointer<Int8>.allocate(capacity: size + 1)
//        var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
//        let addr = UnsafeMutablePointer<sockaddr>.allocate(capacity: MemoryLayout<sockaddr>.size)
//        
//        defer {
//            buffer.deallocate(capacity: size + 1)
//            addr.deallocate(capacity: MemoryLayout<sockaddr>.size)
//        }
//        
//        let success = Darwin.recvfrom(
//            fd,
//            buffer,
//            size,
//            flags,
//            addr,
//            &addrLen
//        )
//        guard success != -1 else {
//            throw SocketError.systemCallError(errno, .recv)
//        }
//        buffer[success] = 0
//        
//        return Message(copy: buffer, length: success + 1, sender: addr.pointee)
//    }
    
}
