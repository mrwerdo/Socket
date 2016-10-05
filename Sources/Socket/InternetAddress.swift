//
//  InternetAddress.swift
//  LibQuickShare
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

public protocol SocketAddress {
    var length: __uint8_t { get }
    var family: DomainAddressFamily { get }
    var contents: sockaddr_storage { get set }
}

public protocol InternetAddress : SocketAddress {
    var port: in_port_t { get set }
}

public struct IPv4Address : InternetAddress {
    public var length: __uint8_t
    public var family: DomainAddressFamily
    public var port: in_port_t
    public var ipAddress: in_addr_t
    
    public init(address: in_addr_t, port: in_port_t) {
        self.length = __uint8_t(MemoryLayout<sockaddr_in>.stride)
        self.family = .inet
        self.port = port
        self.ipAddress = address
    }
    public init(address: String, port: in_port_t) {
        let number = inet_addr(address)
        self.init(address: number, port: port)
    }
}

public struct IPv6Address : InternetAddress {
    public var length: __uint8_t
    public var family: DomainAddressFamily
    public var port: in_port_t
    public var flowinfo: __uint32_t
    public var ipAddress: in6_addr
    public var scopeID: __uint32_t
}

public struct LocalAddress : SocketAddress {
    public var length: __uint8_t
    public var family: DomainAddressFamily
    public var path: ContiguousArray<CChar>
    
    init(path: String) {
        self.path = path.utf8CString
        self.family = .local
        self.length = __uint8_t(MemoryLayout<sockaddr_un>.stride)
    }
}

public struct SystemAddress : SocketAddress {
    public var length: __uint8_t
    public var family: DomainAddressFamily
    public var sysaddr: UInt16
    public var reserved: [UInt32]
}

public struct UnknownAddress : SocketAddress {
    public var contents: sockaddr_storage
    public var length: __uint8_t {
        return contents.ss_len
    }
    public var family: DomainAddressFamily {
        return DomainAddressFamily(rawValue: Int32(contents.ss_family))
    }
}

public struct InterfaceAddress {
    public var name: String
    public var flags: UInt32
    public var address: sockaddr_storage
    public var netmask: sockaddr_storage?
    public var destinationAddress: sockaddr_storage?
    public var data: if_data?
    
    public init(_ ifaddr: Support.ifaddrs) {
        name = String(utf8String: ifaddr.ifa_name)!
        flags = ifaddr.ifa_flags
        
        address = ifaddr.ifa_addr.withMemoryRebound(to: sockaddr_storage.self, capacity: 10) { (ptr) in
            return ptr.pointee
        }
        netmask = ifaddr.ifa_netmask.withMemoryRebound(to: sockaddr_storage.self, capacity: -1) { (ptr) in
            return ptr.pointee
        }
        destinationAddress = ifaddr.ifa_dstaddr.withMemoryRebound(to: sockaddr_storage.self, capacity: -1) { ptr in
            return ptr.pointee
        }
        if let a_data = ifaddr.ifa_data {
            data = a_data.bindMemory(to: if_data.self, capacity: -1).pointee
        }
    }
}

public struct AddressInfo {
    public var flags: CInt
    public var family: DomainAddressFamily
    public var type: SocketType
    public var communicationProtocol: CommunicationProtocol
    public var address: SocketAddress
    public var canonicalName: String?
    
    public init(family: DomainAddressFamily, type: SocketType, protocol: CommunicationProtocol, address: SocketAddress, canonicalName: String? = nil) {
        self.flags = 0
        self.family = family
        self.type = type
        self.communicationProtocol = `protocol`
        self.address = address
        self.canonicalName = canonicalName
    }
    
    public init(local a: LocalAddress, type: SocketType, protocol: CommunicationProtocol) {
        family = a.family
        address = a
        flags = 0
        communicationProtocol = `protocol`
        self.type = type
    }
}

// -----------------------------------------------------------------------------
// mark: Initializer Convience Methods
// -----------------------------------------------------------------------------

extension SocketAddress {
    /// Cast's `contents` to the given `type` and `size`, then execute `block`
    /// on the resulting pointer.
    mutating func execute<T, Result>(castingTo type: T.Type, size: Int? = nil, code block: ((UnsafeMutablePointer<T>) throws -> Result)) rethrows -> Result {
        return try withUnsafeMutablePointer(to: &contents) { contentsPtr in
            let size = (size == nil) ? MemoryLayout<T>.size : size!
            return try contentsPtr.withMemoryRebound(to: type, capacity: size) { ptr in
                return try block(ptr)
            }
        }
    }
}

public typealias sockaddr_storage_ptr = UnsafePointer<sockaddr_storage>

public protocol SockaddrInitalizer : SocketAddress {
    associatedtype sockaddr_type
    
    init(sockaddr sa: sockaddr)
    init(_ sa: sockaddr_type)
}

extension SockaddrInitalizer {
    public init(sockaddr sa: sockaddr) {
        var sa = sa
        let address = withUnsafePointer(to: &sa) { (ptr: UnsafePointer<sockaddr>) in
            return ptr.withMemoryRebound(to: sockaddr_type.self, capacity: MemoryLayout<sockaddr_type>.size) { (ptr2: UnsafeMutablePointer<sockaddr_type>) in
                return ptr2.pointee
            }
        }
        self.init(address)
    }
}

extension IPv4Address : SockaddrInitalizer {
    public init(_ sa: sockaddr_in) {
        length = sa.sin_len
        family = DomainAddressFamily(rawValue: Int32(sa.sin_family))
        port = sa.sin_port
        ipAddress = sa.sin_addr.s_addr
    }
}

extension IPv6Address : SockaddrInitalizer {
    public init(_ sa: sockaddr_in6) {
        length = sa.sin6_len
        family = DomainAddressFamily(rawValue: Int32(sa.sin6_family))
        port = sa.sin6_port
        ipAddress = sa.sin6_addr
        flowinfo = sa.sin6_flowinfo
        scopeID = sa.sin6_scope_id
    }
}

extension LocalAddress : SockaddrInitalizer {
    public init(_ sa: sockaddr_un) {
        length = sa.sun_len
        family = DomainAddressFamily(rawValue: Int32(sa.sun_family))
        path = sa.getPath()
    }
}

extension SystemAddress : SockaddrInitalizer {
    public init(_ sa: sockaddr_sys) {
        length = sa.ss_len
        family = DomainAddressFamily(rawValue: Int32(sa.ss_family))
        sysaddr = sa.ss_sysaddr
        reserved = [UInt32].init(repeating: 0, count: 8)
        reserved[0] = sa.ss_reserved.0
        reserved[1] = sa.ss_reserved.1
        reserved[2] = sa.ss_reserved.2
        reserved[3] = sa.ss_reserved.3
        reserved[4] = sa.ss_reserved.4
        reserved[5] = sa.ss_reserved.5
        reserved[6] = sa.ss_reserved.6
    }
}

extension AddressInfo {
    public init(_ ai: addrinfo) {
        flags = ai.ai_flags
        family = DomainAddressFamily(rawValue: ai.ai_family)
        type = SocketType(rawValue: ai.ai_socktype)
        communicationProtocol = CommunicationProtocol(rawValue: ai.ai_protocol)
        canonicalName = nil
        switch family {
        case .inet:
            address = IPv4Address(sockaddr: ai.ai_addr.pointee)
        case .inet6:
            address = IPv6Address(sockaddr: ai.ai_addr.pointee)
        case .local:
            address = LocalAddress(sockaddr: ai.ai_addr.pointee)
        case .system:
            address = SystemAddress(sockaddr: ai.ai_addr.pointee)
        default:
            address = ai.ai_addr.withMemoryRebound(to: sockaddr_storage.self, capacity: -1) { ptr in
                return UnknownAddress(contents: ptr.pointee)
            }
        }
    }
}

/// Copies `value` into `storage`.
private func assign<Variable, Value>(_ storage: inout Variable, with value: Value) {
    var value = value
    storage = withUnsafePointer(to: &value) { (valuePtr: UnsafePointer<Value>) in
        return valuePtr.withMemoryRebound(to: Variable.self, capacity: MemoryLayout<Variable>.size) { (ptr: UnsafeMutablePointer<Variable>) -> Variable in
            return ptr.pointee
        }
    }
}

// -----------------------------------------------------------------------------
// mark: Sockaddr getters
// -----------------------------------------------------------------------------

extension IPv4Address {
    public var contents: sockaddr_storage {
        get {
            let s = sockaddr_in(sin_len: length,
                                sin_family: sa_family_t(family.systemValue),
                                sin_port: port,
                                sin_addr: in_addr(s_addr: ipAddress),
                                sin_zero: (0,0,0,0,0,0,0,0))
            var storage = sockaddr_storage()
            assign(&storage, with: s)
            return storage
        }
        set {
            var s = sockaddr_in()
            assign(&s, with: newValue)
            self = IPv4Address.init(s)
        }
    }
}

extension IPv6Address {
    public var contents: sockaddr_storage {
        get {
            let s = sockaddr_in6(sin6_len: length,
                                 sin6_family: sa_family_t(family.systemValue),
                                 sin6_port: port,
                                 sin6_flowinfo: flowinfo,
                                 sin6_addr: ipAddress,
                                 sin6_scope_id: scopeID)
            
            var storage = sockaddr_storage()
            assign(&storage, with: s)
            return storage
        }
        set {
            var s = sockaddr_in6()
            assign(&s, with: newValue)
            self = IPv6Address.init(s)
        }
    }
}

extension LocalAddress {
    public var contents: sockaddr_storage {
        get {
            var s = sockaddr_un()
            s.sun_family = sa_family_t(family.systemValue)
            s.sun_len = length
            s.setPath(path)
            var storage = sockaddr_storage()
            assign(&storage, with: s)
            return storage
        }
        set {
            var s = sockaddr_un()
            assign(&s, with: newValue)
            self = LocalAddress.init(s)
        }
    }
}

extension SystemAddress {
    public var contents: sockaddr_storage {
        get {
            let s = sockaddr_sys(ss_len: length,
                                 ss_family: u_char(family.systemValue),
                                 ss_sysaddr: sysaddr,
                                 ss_reserved: (reserved[0],
                                               reserved[1],
                                               reserved[2],
                                               reserved[3],
                                               reserved[4],
                                               reserved[5],
                                               reserved[6]))
            var storage = sockaddr_storage()
            assign(&storage, with: s)
            return storage
        }
        set {
            var s = sockaddr_sys()
            assign(&s, with: newValue)
            self = SystemAddress.init(s)
        }
    }
}
