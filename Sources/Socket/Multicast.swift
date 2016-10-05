//
//  Multicast.swift
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
import Support

extension Socket {
    public func setLoopBack(_ value: Bool) throws {
        var loop: u_char = value ? 1 : 0
        try setSocketOption(IPPROTO_IP,
                            option: IP_MULTICAST_LOOP,
                            value: &loop,
                            valueLen: socklen_t(MemoryLayout<u_char>.stride))
    }
    
    public func setTimeToLive(_ ttl: UInt8) throws {
        var value = ttl
        try setSocketOption(IPPROTO_IP,
                            option: IP_MULTICAST_TTL,
                            value: &value,
                            valueLen: socklen_t(MemoryLayout<UInt8>.stride))
    }
    
    public func enableMulticast(on address: in_addr, usingInterface device: in_addr) throws {
        var mreq = ip_mreq(imr_multiaddr: address, imr_interface: device)
        try setSocketOption(IPPROTO_IP,
                            option: IP_ADD_MEMBERSHIP,
                            value: &mreq,
                            valueLen: socklen_t(MemoryLayout<ip_mreq>.stride))
    }
    
    public func setShouldBlock(_ value: Bool) throws {
        let flags: Int32 = qsfcntl(fd, F_GETFL, 0)
        let options: Int32
        switch value {
        case true:
            options = flags ^ O_NONBLOCK
        case false:
            options = flags | O_NONBLOCK
        }
        guard qsfcntl(fd, F_SETFL, Int(options)) == 0 else {
            throw SocketError.systemCallError(errno, .setOption)
        }
    }
}
