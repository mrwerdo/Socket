//
//  NetworkUtilities.swift
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
import Support

public enum NetworkUtilitiesError : Error {
    /// Thrown when an error occured within the Darwin module.

    /// Thrown by `gethostname()` when the system call failed. The associate
    /// value returned is from `errno`, use `strerror()` to obtain a 
    /// description.
    case getHostNameFailed(Int32)
    /// Thrown by `sethostname()` when the system call failed. The associate
    /// value returned is from `errno`, use `strerror()` to obtain a
    /// description.
    case setHostnameFailed(Int32)
    /// Thrown by `getaddrinfo(hostname:servname:hints:)`. The associate
    /// value is an error number returned from the system call. Use 
    /// `gai_strerror()` to access a description.
    ///
    /// **See Also**: x-man-page://getaddrinfo
    case getAddressInfoFailed(Int32)
    
    @available(*, unavailable, renamed: "GetAddressInfoFailed")
    case getAddressFailed(Int32)
    /// Thrown by `getnameinfo(
    case getNameInfoFailed(Int32)
	/// Thrown by `gethostbyname(_:family:)`. The associate value contains
	/// an error number. Use `herror()` or `hstrerror()` to print or obtain
	/// a string respectively.
	case getHostByNameFailed(Int32)
    /// Occurs when an invalid parameter is given.
    case parameterError(String)
}

/// Returns the address of `obj`.
///
/// This function is fundamentally unsafe, and
/// should be only used to get the address of a c structure. You must ensure 
/// that the object exsists throughout the whole lifetime this pointer will 
/// be used, which is typically done by ensuring the object lives within the
/// same, or higher scope as the pointer.
public func unsafeAddressOfCObj<T: Any>(_ obj: UnsafeMutablePointer<T>) ->
    UnsafeMutablePointer<T> {
    return obj
}

/// Converts the bytes of `value` from network order to host order.
public func ntohs(_ value: CUnsignedShort) -> CUnsignedShort {
    if value.byteSwapped == value.bigEndian && value == value.littleEndian {
        return value.littleEndian
    } else {
        return value.bigEndian
    }
}
/// Converts the bytes of `value` from host order to network order.
public func htons(_ value: CUnsignedShort) -> CUnsignedShort {
    // Network byte order is always `bigEndain`.
    return value.bigEndian
}

extension String {
    /// Returns an underlying c buffer.
    /// - Warning: Deallocate the pointer when done to aviod memory leaks.
    private var getCString: (ptr: UnsafeMutablePointer<Int8>, len: Int) {
        return self.withCString { (ptr: UnsafePointer<Int8>) ->
            (UnsafeMutablePointer<Int8>, Int) in
            let len = self.utf8.count
            let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: len + 1)
            for i in 0..<len {
                buffer[i] = ptr[i]
            }
            buffer[len] = 0
            return (buffer, len)
        }
    }
}

public struct AddressHints {
    var type: SocketType
    var communicationProtocol: CommunicationProtocol
    var family: DomainAddressFamily
    var flags: Int32
}

private func convert(_ results: [AddressInfo], andAssign port: in_port_t) -> [AddressInfo] {
    let k: [AddressInfo] = results.flatMap { addrInfo in
        var addrInfo = addrInfo
        if var s = addrInfo.address as? InternetAddress {
            s.port = port
            addrInfo.address = s
            return addrInfo
        }
        return nil
    }
    return k
}

public func find(host name: String, on port: in_port_t, with hints: AddressHints? = nil) throws -> [AddressInfo] {
    var hts = Darwin.addrinfo()
    if let addressInfo = hints {
        hts.ai_socktype   = addressInfo.type.systemValue
        hts.ai_protocol   = addressInfo.communicationProtocol.systemValue
        hts.ai_family     = addressInfo.family.systemValue
        hts.ai_flags      = addressInfo.flags
    }
    let results = try getaddrinfo(host: name, service: nil, hints: hts)
    return convert(results, andAssign: port)
}

public func find(service: String, on port: in_port_t, with hints: AddressHints? = nil) throws -> [AddressInfo] {
    var hts = Darwin.addrinfo()
    if let addressInfo = hints {
        hts.ai_socktype   = addressInfo.type.systemValue
        hts.ai_protocol   = addressInfo.communicationProtocol.systemValue
        hts.ai_family     = addressInfo.family.systemValue
        hts.ai_flags      = addressInfo.flags
    }
    let results = try getaddrinfo(host: nil, service: service, hints: hts)
    return convert(results, andAssign: port)
}

/// Obtains a list of IP addresses and port number, given the requirements
/// `hostname`, `serviceName` and `hints`.
///
/// The list of addresses given will be filtered out by the options specificed.
/// If `serviceName` is specified, then only hosts with that service will be
/// returned, this is likewise for `hostname` too.
///
/// `hints` provides additional specification to the type of address returned.
/// You may set these fields to filter for a specific type of address:
///
/// - `ai_family` to control the protocol family used. If this
///     value can be any, then it should be set to `PF_UNSPEC`. This is
///     equivelent to `DomainAddressFamily`.
/// - `ai_socktype` denotes the allowed socket type given. Zero allows
///     any type. This is equivelent to `SocketType`.
/// - `ai_protocol` indicates the transport layer desired. Zero again
///     allows any protocol. This is equivelent to `CommunicationProtocol`.
/// - `ai_flags` allows additional filtering. See this
///     [page](x-man-page://3/getaddrinfo)
///
///
/// - Attention:    `hostname` and `servername` may not be both nil at the same
///                 time.
///
/// - parameters:
///     - hostname:     Either a valid host name or a numeric host address,
///                     cosisting of a dotted decimal IPv4 address or a IPv6
///                     address.
///     - servicename:  Either a decimal port number or a service name (see
///                     [services](x-man-page://5/services))
///
///
/// - Throws:
///     - `NetworkUtilities.ParmeterError`
///     - `NetworkUtilities.GetAddressInfoFailed`
public func getaddrinfo(host hostname: UnsafePointer<CChar>?, service serviceName: UnsafePointer<CChar>?,
                          hints: addrinfo) throws -> [AddressInfo] {
    
    guard !(hostname == nil && serviceName == nil) else {
        throw NetworkUtilitiesError.parameterError(
            "Host name and server name cannot be nil at the same time!"
        )
    }
    var hints = hints
    let ptr = UnsafeMutablePointer<UnsafeMutablePointer<addrinfo>?>.allocate(capacity: 1)
    defer {
        ptr.deallocate(capacity: 1)
    }
    let error = Darwin.getaddrinfo(hostname, serviceName, &hints, ptr)
    guard error == 0 else {
        throw NetworkUtilitiesError.getAddressInfoFailed(error)
    }
    
    if let first = ptr.pointee {
        let k = sequence(state: first, next: { (state: inout UnsafeMutablePointer<addrinfo>?) -> AddressInfo? in
            if let a = state?.pointee {
                state = state?.pointee.ai_next
                return AddressInfo(a)
            }
            return nil
        })
        return Array(k)
    }
    
    return []
}

public func getnameinfo(_ info: AddressInfo, flags: Int32 = 0) throws
    -> (hostname: String?, servicename: String?) {
        var hostnameBuff = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
        var servicenameBuff = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXSERV))
        
        memset(hostnameBuff, 0, Int(NI_MAXHOST))
        memset(servicenameBuff, 0, Int(NI_MAXSERV))
        
        defer {
            hostnameBuff.deallocate(capacity: Int(NI_MAXHOST))
            servicenameBuff.deallocate(capacity: Int(NI_MAXSERV))
        }
        var info = info
        let success = withUnsafePointer(to: &info.address.contents) { (ptr: sockaddr_storage_ptr) -> CInt in
            return ptr.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size, { (saddr: UnsafeMutablePointer<sockaddr>) -> Int32 in
                return Darwin.getnameinfo(
                    saddr,
                    socklen_t(info.address.length),
                    hostnameBuff,
                    UInt32(NI_MAXHOST) * UInt32(MemoryLayout<Int8>.size),
                    servicenameBuff,
                    UInt32(NI_MAXSERV) * UInt32(MemoryLayout<Int8>.size),
                    flags
                )
            })
            
        }
        
        
        guard success == 0 else {
            throw NetworkUtilitiesError.getNameInfoFailed(success)
        }
        
        return (
            String(cString: hostnameBuff),
            String(cString: servicenameBuff)
        )
}


/// Performs the call `Darwin.gethostname()`.
///
/// The `gethostname()` function is used get the host name for the current 
/// processor.
/// - Returns: The hostname, or nil if it could not be converted to a c string.
/// - Throws: 
///     `NetworkUtilitiesError.LibraryError` when `Darwin.gethostname()` fails. 
///         `errno` is returned as an associate value, see the man pages for 
///         the meaning of the error codes.
public func gethostname() throws -> String? {
    let maxlength = Int(sysconf(_SC_HOST_NAME_MAX))
    var cstring = [Int8](repeating: 0, count: maxlength)
    let result = Darwin.gethostname(
        &cstring,
        maxlength
    )
    guard result == 0 else {
        throw NetworkUtilitiesError.getHostNameFailed(errno)
    }
    return String(cString: &cstring)
}
/// Performs the call `Darwin.sethostname()`.
///
/// The `sethostname(hostname:)` function is used to set the name host name for 
/// the current processor. This call is restricted to the super-user, and is
/// normally only used when the system is bootstrapped.
/// - Throws: 
///     - `NetworkUtilitiesError.ParameterError` when the length of the string
///         supplied is greater than `sysconf(_SC_HOST_NAME_MAX)`.
///     - `NetworkUtilitiesError.LibraryError` when `Darwin.sethostname()`
///         fails. `errno` is returned as an associate value, see the man pages
///         for the corresponding error.
public func sethostname(_ hostname: String) throws {
    let maxlength = Int(sysconf(_SC_HOST_NAME_MAX))
    let len = hostname.lengthOfBytes(using: String.Encoding.utf8)
    guard len <= maxlength else {
        throw NetworkUtilitiesError.parameterError(
      "The length of hostname cannot be greater than sysconf(_SC_HOST_NAME_MAX)"
        )
    }
    try hostname.withCString { (cstring: UnsafePointer<Int8>) -> Void in
        let result = Darwin.sethostname(cstring, Int32(len))
        guard result == 0 else {
            throw NetworkUtilitiesError.setHostnameFailed(errno)
        }
    }
}

extension String {
    /// Returns a `String` given a c error `number`.
    @available(*, deprecated: 10.10)
    public static func fromCError(_ number: Int32) -> String {
        return String(cString: strerror(number))
    }
}

public struct HostEntry {
    public var name: String? = ""
    public var aliases: [String] = []
    public var type: DomainAddressFamily?
    public var addresses: [String] = []
}

/// Returns host information associated with the given `hostname`.
///
/// Only IPv4 and IPv6 addresses are supported, failing to meet this 
/// throws an error.
/// 
/// - parameters:
///		- hostname:			The hostname to look up. This can be either
///							a name, an IPv4 address or an IPv6 address.
///							In the latter two cases, family must match.
///		- family:			The type of address given in `hostname`.
///
///	- Returns:
///							A HostEntry, which contains information
///							about the specified host.
/// - Throws:
///		- `NetworkUtilitiesError.GetHostByNameFailed`
public func gethostbyname(_ hostname: String, family: DomainAddressFamily) throws
    -> HostEntry {
        switch family {
        case .inet, .inet6: break
        default:
			throw NetworkUtilitiesError.parameterError("Only IPv4 and IPv6 addresses are supported")
        }
        let ent = Darwin.gethostbyname2(hostname, family.systemValue)
        guard ent != nil else {
			throw NetworkUtilitiesError.getHostByNameFailed(h_errno)
        }
        
        var record = HostEntry()
        record.name = String(cString: (ent?.pointee.h_name)!)
        switch ent?.pointee.h_addrtype ?? 0 {
        case PF_INET:
            record.type = .inet
        case PF_INET6:
            record.type = .inet6
        default:
            break
            //preconditionFailure(
            // "Found an address which is not listed in the documentation"
            //)
        }
        var counter = 0
        while ent?.pointee.h_aliases[counter] != nil {
            if let str = String(validatingUTF8: (ent?.pointee.h_aliases[counter]!)!) {
                record.aliases.append(str)
            }
            counter += 1
        }
        
        counter = 0
        typealias InAddrPtrType = UnsafeMutablePointer<Darwin.in_addr>
        
        ent?.pointee.h_addr_list.withMemoryRebound(to: Optional<UnsafeMutablePointer<Darwin.in_addr>>.self, capacity: 10) { (addr_list) in
            while addr_list[counter] != nil {
                var address = addr_list[counter]!.pointee
                if let str = inet_ntop(&address, type: family) {
                    record.addresses.append(str)
                }
                counter += 1
            }
        }
        
        return record
}

/// Returns a string representation of `address`, or nil if it could not be
/// converted. Currently understood address formats are `INET` and `INET6`.
/// - parameters:
///     - address:  The address to be converted.
///     - type:     The type of address given. The only valid values are `INET`
///                 or `INET6`, all other values are undefined (subject to 
///                 future change).
/// - returns:
///                 A string representation of `address`, or nil if it could 
///                 not be converted.
public func inet_ntop(_ address: UnsafePointer<in_addr>, type: DomainAddressFamily)
    -> String? {
        var length: Int32
        switch type {
        case .inet:
            length = INET_ADDRSTRLEN
        case .inet6:
            length = INET6_ADDRSTRLEN
        default:
            return nil
        }
        var cstring = [Int8](repeating: 0, count: Int(length))
        let result = Darwin.inet_ntop(
            type.systemValue,
            address,
            &cstring,
            socklen_t(length)
        )
        guard result != nil else {
            return nil
        }
        return String(cString: &cstring)
}

public func getifaddrs() -> [InterfaceAddress]? {
    if let linkedlist = qs_getifaddrs() {
        var interface: UnsafeMutablePointer<ifaddrs>? = linkedlist
        var interfaces = [InterfaceAddress]()
        while interface != nil {
            interfaces.append(InterfaceAddress(interface!.pointee))
            interface = interface!.pointee.ifa_next
        }
        freeifaddrs(linkedlist)
        return interfaces
    } else {
        return nil
    }
}

// end of file
