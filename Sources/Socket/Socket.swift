//
//  Socket.swift
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
//  FITNESS FOR A PARTICULAR PURPOSE AND NON INFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CqONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Support

protocol SystemEnumerable {
    var systemValue: Int32 { get }
}

func ==(lhs: SystemEnumerable, rhs: SystemEnumerable) -> Bool {
    return lhs.systemValue == rhs.systemValue
}

/// The `type` of socket, which specifies the semantics of communication.
public enum SocketType : SystemEnumerable {
    /// Sends packets reliably and ensures they arrive in the same order that
    /// they were sent in.
    case stream
    /// Sends packets unreliably and quickly, not guarenteeing the arival or
    /// the arival order of any packets sent.
    case datagram
    /// Provides access to the raw communication model. This is restricted to
    /// the super-user. It creates no additional header information, and as 
    /// such, can be used to inspect and send packets of all protocol types.
    /// **Note**:   Depending on the system, the actual ability of a raw socket
    ///             may vary. They are not very portable.
    case raw
    
    /// Used to represent a protocol not listed above.
    case other(Int32)
    
    init(rawValue: Int32) {
        switch rawValue {
        case SOCK_STREAM:
            self = .stream
        case SOCK_DGRAM:
            self = .datagram
        case SOCK_RAW:
            self = .raw
        default:
            self = .other(rawValue)
        }
    }
    
    /// Returns the integer associated with `self` listed in the 
    /// `<sys/socket.h>` header file.
    var systemValue: Int32 {
        switch self {
        case .stream:
            return SOCK_STREAM
        case .datagram:
            return SOCK_DGRAM
        case .raw:
            return SOCK_RAW
        case .other(let n):
            return n
        }
    }
}

/// The currently understood communication domains within which communication
/// will take place. These parameters are defined in <sys/socket.h>
public enum DomainAddressFamily : SystemEnumerable {
    /// Host-internal protocols, formerly called UNIX
    case local
    /// Internet Version 4 Protocol
    case inet
    /// Internet Version 6 Protocol
    case inet6
    /// The unspecified protocl, signifying that any protocol is accepted.
    case unspecified
    /// The system protocol used in kernal world.
    case system
    /// Used to specify different protocol to use.
    case other(Int32)
    
    init(rawValue: Int32) {
        switch rawValue {
        case PF_LOCAL:
            self = .local
        case PF_INET:
            self = .inet
        case PF_INET6:
            self = .inet6
        case PF_UNSPEC:
            self = .unspecified
        case PF_SYSTEM:
            self = .system
        default:
            self = .other(rawValue)
        }
    }
    
    /// Returns the integer associated with `self` for use with the networking
    /// calls.
    var systemValue: Int32 {
        switch self {
        case .local:
            return PF_LOCAL
        case .inet:
            return PF_INET
        case .inet6:
            return PF_INET6
        case .unspecified:
            return PF_UNSPEC
        case .system:
            return PF_SYSTEM
        case .other(let n):
            return n
        }
    }
}

/// The specific protocol methods used for transfering data. The very common
/// protocols are listed below. For all the protocols, see /etc/protocols and 
/// <inet/in.h>.
public enum CommunicationProtocol {
    /// Transmission Control Protocol
    case tcp
    /// User Datagram Protocol
    case udp
    /// Raw Protocol
    case raw
    /// Used to specify another protocol to use.
    case other(Int32)
    
    init(rawValue: Int32) {
        switch rawValue {
        case IPPROTO_TCP:
            self = .tcp
        case IPPROTO_UDP:
            self = .udp
        case IPPROTO_RAW:
            self = .raw
        default:
            self = .other(rawValue)
        }
    }
    
    /// Returns the integer associated with `self` for use with the networking
    /// calls.
    var systemValue: Int32 {
        switch self {
        case .tcp:
            return IPPROTO_TCP
        case .udp:
            return IPPROTO_UDP
        case .raw:
            return IPPROTO_RAW
        case .other(let n):
            return n
        }
    } 
}

public enum SocketFunction {
    case bind, connect
    case send, recv
    case close, shutdown
    case `init`, unlink
    case accept, listen
    case setOption, getOption
    case select
}

public enum SocketError : Error, CustomDebugStringConvertible {
    /// Thrown when a system call fails. The associate value holds the value
    /// of errno after the operation failed.
    case systemCallError(Int32, SocketFunction)
    /// Thrown when an invalid parameter is given.
    case parameter(String, SocketFunction)
    /// Thrown when bind exhausts potential addresses to connect to.
    case exhaustedAddresses([Int32], SocketFunction)

    public var debugDescription: String {
        switch self {
        case .systemCallError(let n, let fc):
            if let errormsg = String(validatingUTF8: strerror(n)) {
                return "SystemCallError(errno: \(n), fc: \(fc), msg: \(errormsg))"
            } else {
                return "undefined error: \(n)"
            }
        case .parameter(let msg, let fc):
            return "Parameter(description: \(msg), inFunction: \(fc))"
        case .exhaustedAddresses(let errors, let fc):
            return "ExhaustedAddresses(inFunction: \(fc), withErrors: \(errors))"
        }
    }
}

/// A class for manipulating sockets, similar to the python module socket.
/// What else is there to say, they're sockets...
public class Socket {

    public          var fd      : Int32
    public          var addressInfo : AddressInfo
    private(set)    lazy var peerAddress: SocketAddress? = nil
        
//        {
//        [unowned self] in
//        var storage = sockaddr_storage()
//        return withUnsafePointer(to: &storage) { (ptr: UnsafePointer<sockaddr_storage>) in
//            let sa = UnsafeMutablePointer<sockaddr>(ptr)
//            var length = socklen_t(MemoryLayout<Darwin.sockaddr_storage>.stride)
//            guard getpeername(self.fd, sa, &length) == 0 else {
//                return nil
//            }
//            
//            var peer = self.addressInfo.address
//            peer.contents = storage
//            return peer
//        }
//        }()
    private(set)    var closed  : Bool
    private         var shouldReuseAddress: Bool = false
    
    /// Constructs an instance from a pre-exsisting file descriptor and address.
    /// - parameter shouldReuseAddress: If not provided, the default is `false`
    public init(socket: Int32, address addr: addrinfo,
                shouldReuseAddress: Bool = false) {
        fd = socket
        addressInfo = AddressInfo(addr)
        closed = false
        self.shouldReuseAddress = shouldReuseAddress
    }
    
    /// Constructs a socket from the given address infomation.
    ///
    /// - Throws:
    ///     Errors are thrown when a system call fails, and are wrapped in the
    ///     error type `SocketError`.
    ///
    public init(info: AddressInfo) throws {
        addressInfo = info
        closed = false
        fd = Darwin.socket(info.family.systemValue,
                           info.type.systemValue,
                           info.communicationProtocol.systemValue)
        guard fd != -1 else {
            throw SocketError.systemCallError(errno, .`init`)
        }
    }
    
//    public convenience init(tcpIPv4 address: String, port: in_port_t) throws {
////        let sockaddress = IPv4Address(address: address, port: port)
//        let info = AddressInfo.init(family: .inet, type: .stream, protocol: .tcp, address: sockaddress)
//        try self.init(info: info)
//    }
    
    /// Copys `address` and initalises the socket from the `fd` given.
    /// - parameter address: The socket's address.
    /// - parameter fd:      A valid socket file descriptor.
    fileprivate init(address: AddressInfo, fd: Int32) {
        self.addressInfo = address
        self.closed = true
        self.fd = fd
    }
    
    /// Re-initalises the socket to a 'new' state, ready for a call to bind
    /// or connect.
    ///
    /// When an attempt to bind or connect the socket fails, the file 
    /// descriptor become unusable. This method overcomes that problem.
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`.
    ///
    fileprivate func initaliseSocket() throws {
        _ = try? close()
        fd = Darwin.socket(
            addressInfo.family.systemValue,
            addressInfo.type.systemValue,
            addressInfo.communicationProtocol.systemValue
        )
        guard fd != -1 else {
            throw SocketError.systemCallError(errno, .`init`)
        }
        closed = false
        try setShouldReuseAddress(shouldReuseAddress)
    }
    
    public enum ShutdownMethod {
        case preventRead
        case preventWrite
        case preventRW
        var systemValue: Int32 {
            switch self {
            case .preventRead:
                return SHUT_RD
            case .preventWrite:
                return SHUT_WR
            case .preventRW:
                return SHUT_RDWR
            }
        }
    }
    
    /// Shuts down the socket, signaling that either all reading has finished,
    /// all writing has finished, or both reading and writing have finished.
    /// A socket is not allowed to write if it has shutdown writing, similarly,
    /// it is not allowed to read if it has shutdown reading.
    /// 
    /// - seealso:
    ///     - `close()`
    ///     - [The shutdown man page][1]
    ///     - This [article][2] provides a good explanation for when to use
    ///         [shutdown][1] and [close][3].
    ///  
    /// [1]: x-man-page://2/shutdown
    /// [2]: https://msdn.microsoft.com/en-us/library/ms738547(VS.85).aspx
    /// [3]: x-man-page://2/close
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`.
    ///
    public func shutdown(_ method: ShutdownMethod) throws {
        guard Darwin.shutdown(fd, method.systemValue) == 0 else {
            throw SocketError.systemCallError(errno, .shutdown)
        }
    }
    
    /// Closes the socket.
    ///
    ///
    /// Closing the socket deletes any associated information with the socket.
    /// Thus, once a socket is closed, it is considered an error to perform any
    /// more operations on it.
    ///
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`.
    ///
    /// - seealso: 
    ///     - `shutdown(_)`
    ///     - [The close manual page][1]
    ///     - This [article][2] provides a good explanation for when to use
    ///         [close][1] and [shutdown][3].
    ///
    /// [1]: x-man-page://2/close
    /// [2]: https://msdn.microsoft.com/en-us/library/ms738547(VS.85).aspx
    /// [3]: x-man-page://2/shutdown
    public func close() throws {
        guard Darwin.close(fd) == 0 else {
            throw SocketError.systemCallError(errno, .close)
        }
    }
    
    deinit {
        _ = try? close()
    }
}

// MARK: - Bind & Connect

extension Socket {
    
    /// Binds the socket to the given address and port without performing any
    /// name resolution.
    ///
    /// - parameter address:    An address to bind to. The `address.addrinfo`
    ///                         must contain a valid ai_addr address, and
    ///                         ai_addrlen must be filled to be the size of the
    ///                         structure.
    /// - parameter port:       A non-negative integer describing the port to
    ///                         bind `self` to. Some values are reseverd for the
    ///                         system and require root privileges.
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`.
    ///
    /// - Seealso:
    ///     - [The bind man page][1]
    ///     - [Commonly known ports]
    ///
    /// [1]: x-man-page://2/bind
    /// [2]: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
    public func bind(shouldUnlinkFile: Bool = false) throws {
        switch addressInfo.address {
        case is InternetAddress:
            try bindTo(internet: &addressInfo.address)
        case is LocalAddress:
            try bindTo(local: &addressInfo.address, shouldUnlink: shouldUnlinkFile)
        default:
            fatalError("This class does not know how your bind the address")
        }
    }
    
    private func bindTo(internet address: inout SocketAddress) throws {
        let length = address.length
        try address.execute(castingTo: sockaddr.self) { (sa: UnsafeMutablePointer<sockaddr>) in
            guard Darwin.bind(fd,
                              sa,
                              socklen_t(length)
                ) == 0 else {
                    throw SocketError.systemCallError(errno, .bind)
            }
        }
    }
    
    private func bindTo(local address: inout SocketAddress, shouldUnlink: Bool) throws {
        var address = address as! LocalAddress
        if shouldUnlink {
            let file = address.path.reduce("") { $0 + "\($1)" }
            try unlink(file, errorOnFNF: false)
        }
        let length = address.length
        try address.execute(castingTo: sockaddr.self) { sa in
            guard Darwin.bind(fd,
                              sa,
                              socklen_t(length)
                ) == 0
                else {
                    throw SocketError.systemCallError(errno, .bind)
            }
        }
    }
    
    /// Unlinks the file at the given url.
    ///
    /// - parameter path:   The file to be removed.
    /// - parameter errorOnFNF: Setting this to `false` causes this function
    ///                         not to error when there is no file to unlink.
    private func unlink(_ path: String, errorOnFNF: Bool = true) throws {
        guard Darwin.unlink(path) == 0 else {
            if !(!errorOnFNF && errno == ENOENT) {
                throw SocketError.systemCallError(errno, .unlink)
            } else {
                return
            }
        }
    }
}
extension Socket {
    
    public func connect() throws {
        switch addressInfo.address {
        case is InternetAddress, is LocalAddress:
            try connectTo(internet: &addressInfo.address)
//        case is LocalAddress:
//            try connectTo(local: &addressInfo.address)
        default:
            fatalError("This class does not know how your bind the address")
        }
    }
    
    private func connectTo(internet address: inout SocketAddress) throws {
        let length = address.length
        try address.execute(castingTo: sockaddr.self) { sa in
            guard Darwin.connect(
                fd,
                sa,
                socklen_t(length)
                ) == 0 else {
                    throw SocketError.systemCallError(errno, .connect)
            }
        }
    }
//    
//    private func connectTo(local address: inout SocketAddress) throws {
//        try address.execute(castingTo: sockaddr.self) { sa in
//            guard Darwin.connect(
//                fd,
//                sa,
//                socklen_t(address.length)
//                ) == 0
//                else {
//                    throw SocketError.systemCallError(errno, .connect)
//            }
//        }
//    }
}

extension Socket {
    /// Sends `data` to the connected peer
    ///
    /// Depending on the protocol, the socket must either be in a connected 
    /// state, or had a previous call to connect (or bind) to specify the
    /// communication address.
    ///
    /// - parameters:
    ///		- data:		A pointer to a buffer to send
    ///		- length:	The length of the buffer (in bytes).
    ///		- flags:	Control options for sending and recieving. 0 is the 
    ///					default.
    ///		- maxSize:	Specifies the maximum packet size when attempting to
    ///					send large amounts of data. If, for example, length
    ///					is twice the size of maxSize, then it will take two
    ///					calls (internally) to send the data. Default is 1024.
    /// - Returns:
    ///					The number of bytes sent.
    ///
    public func send(_ data: UnsafeRawPointer, length: size_t, flags: Int32 = 0,
                     maxSize: size_t = 1024) throws -> ssize_t {
        var data = data 
        var bytesLeft = length
        var bytesSent: size_t = 0
        
        loop: while (length > bytesSent) {
            let len = bytesLeft < maxSize ? bytesLeft : maxSize
            let success = Darwin.sendto(
                fd,
                data,
                len,
                flags,
                nil, // When nil, the address parameter is autofilled,
                // if it exsists
                0
            )
            guard success != -1 else {
                throw SocketError.systemCallError(errno, .send)
            }
            data = data.advanced(by: success)
            bytesSent += success
            bytesLeft -= success
        }
        return bytesSent
    }
    /// Sends `data` to the specified peer.
    ///
    /// If the socket is a connectionless socket, then it is acceptable
    /// to provide different values for the address parameter. On the 
    /// other hand, if the socket is connection orientated, the address
    /// connected to must be provided. This is typically `self.address`.
    /// The method `send(data:length:flags:maxSize)` has been provided 
    /// for conviently calling `sendto`.
    ///
    /// - parameters:
    ///		- address:		The address to send data to.
    ///		- data:			A pointer to the buffer to send.
    ///		- length:		The length of the buffer in bytes.
    ///		- flags:		Controls additional options for sending
    ///						data. Default is 0.
    ///		- maxSize:		The maximum size of each packet (in bytes) when 
    ///						sending large amounts of data. If a buffer is two
    ///						big to send, then it will be split into multiple
    ///						packets.
    /// - Returns:
    ///						The number of bytes sent.
    ///
    public func sendTo(_ info: AddressInfo,
                       data: UnsafeRawPointer,
                       length: size_t,
                       flags: Int32 = 0,
                       maxSize: size_t = 1024) throws -> size_t {
        var data = data 
        var bytesleft = length
        var bytesSent = 0
        var info = info
        let length = info.address.length
        try info.address.execute(castingTo: sockaddr.self) { sa in
            loop: while (length > bytesSent) {
                let len = bytesleft < maxSize ? bytesleft : maxSize
                let success = Darwin.sendto(
                    fd,
                    data,
                    len,
                    flags,
                    sa,
                    socklen_t(length)
                )
                guard success != -1 else {
                    throw SocketError.systemCallError(errno, .send)
                }
                data = data.advanced(by: success)
                bytesSent += success
                bytesleft -= success
            }
        }
        
        
        return bytesSent
    }
    /// Sends `msghdr` to the specified peer.
    ///
    /// Currently, this method provides a convience wrapper to calling
    ///	`Darwin.sendmsg()`. Do not rely on this. If you are using this method
    /// you probally know more about it than I do, and you should probally write
    /// the implementation for it.
    ///
    /// - parameters:
    ///		- msg:			A msghdr object which specifies a series of messages
    ///						and their destination.
    ///		- flags:		Controls additional parameters on the send behaviour.
    ///						Default is 0.
    ///		- maxSize:		Specifies the maximum packet size allowed to be sent
    ///						(measured in bytes).
    ///						Buffers which exceed this value will be split to be 
    ///						less than or equal to this length.
    /// - Returns:
    ///						The number of bytes sent.
    ///
    /// - Todo: This implementation is a poor one. I do not have enough 
    ///			understanding/willpower to implement it correctly. It should 
    ///			attempt to break each packet into a size of 1024, and send 
    ///			individually.
    public func send(_ msg: inout msghdr, flags: Int32 = 0, maxSize: size_t = 1024)
        throws -> size_t {
            
            // FIXME: Send message must be in a while loop
            // This function must keep sending data until either an error
            // occurred or all data has been sent.
            
            let isSuccess = Darwin.sendmsg(fd, &msg, flags)
            guard isSuccess != -1 else {
                throw SocketError.systemCallError(errno, .send)
            }
            return isSuccess
    }
    /// Sends a string to the peer.
    ///
    /// This method adhers to the same requirements as the other, more advanced 
    /// `sendTo(_:data:length:flags:maxSize:)` method. The socket must have had
    /// it's address set, that is, if it's a connectionless socket, a call to `bind`
    /// or `connect`, and if its a connection orientated socket, it must be connected
    /// to a peer.
    ///
    /// - parameters:
    ///		- str:			The string to send. It's length is decoded using the
    ///						NSUTF8StringEncoding interpretation.
    ///		- flags:		Controls additional parameters determining the 
    ///						behaviour of `send`.
    ///		- maxSize:		Specifies the maximum size of packets. If a buffer
    ///						exceeds this size, then it will be split into this size
    ///						until the whole buffer is sent (unless a failure occurs).
    ///	- Returns:
    ///						The number of bytes sent.
    ///
    @discardableResult public func send(_ str: String, flags: Int32 = 0, maxSize: size_t = 1024) throws -> size_t {
        let length = str.lengthOfBytes(using: String.Encoding.utf8)
        return try self.send(str, length: length, flags: flags, maxSize: maxSize)
    }
    
    /// Sends `data` to the peer.
    ///
    /// Allows the sending of data from the host to the peer. Attempting to send binary
    /// data this way is not a good idea (unless the format is exactly the same on the
    /// peer machine). It should instead be encoded, for example, by using base 64
    /// encoding.
    ///
    /// This method adhers to the same requirements as the other, more advanced 
    /// function `sendTo(_:data:length:flags:maxSize:)`. The socket must have had its
    /// address set, either by a call to `connect` or by a call to `bind`.
    ///
    /// - parameters: 
    ///		- data:			The data to send.
    ///		- flags:		Provides additional control parameters for `send`.
    ///		- maxSize:		Specifies the maximum size of packets allow to be sent.
    ///						Buffers which exceed this value will be split into small
    ///						sizes, until the whole buffer is sent.
    /// - Returns:
    ///						The number of bytes sent.
    ///
    public func send(_ data: Data, flags: Int32 = 0, maxSize: size_t = 1024) throws -> size_t {
        let len = data.count
        return try self.send((data as NSData).bytes, length: len, flags: flags, maxSize: maxSize)
    }
}

extension Socket {
    /// Contains a message received from a peer.
    public class Message {
        public typealias Element = Int8
        public typealias Index = Int
        /// The data buffer received from the peer.
        /// It is null terminated at `data[length]`, thus, to retrive
        /// all the data and ignore the termiator, you should use `data[length-1]`.
        public var data: UnsafeMutablePointer<Int8>
        public var length: Int
        /// The sender who sent this message.
        public private(set) var sender: sockaddr?
        
        /// Claims ownership of `data`, and initalizes the object with `length` and 
        /// `sender`.
        init(claim data: UnsafeMutablePointer<Int8>, length: Int,
                   sender: sockaddr?) {
            self.data = data
            self.length = length
            self.sender = sender
        }
        /// Copies `data` and initalizes the object with `length` and `sender`.
        init(copy data: UnsafeMutablePointer<Int8>, length: Int,
                  sender: sockaddr?) {
            self.data = UnsafeMutablePointer<Int8>.allocate(capacity: length)
            self.length = length
            self.sender = sender
            memcpy(self.data, data, length)
        }
        deinit {
            data.deallocate()
        }
    }
    /// Returns any data which has been received from the peer(s).
    ///
    /// Returns any data received by the system destined for this socket. If the
    /// socket is using Transmisison Control Protocol (TCP), and the client 
    /// disconnected, then this method returns `nil`. It will not return `nil`
    /// under any other circumstances.	
    ///
    /// If the socket is using a connectionless orientated protocol, the socket
    /// must first be bound to an address (using `bind`) prior before calling 
    ///	receive.
    ///
    /// - parameters:
    ///		- maxSize:		Specifices the maximum size of data to be returned.
    ///		- flags:		Provides additional control to the behaviour of 
    ///						`recvfrom`. Default is 0.
    /// - Returns:
    ///						A `Message` object, which contains the buffer and
    ///						the sender. `Nil` iff the connection protocol is TCP
    ///						and the client disconnected.
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`
    ///
    public func recv(_ maxSize: Int, flags: Int32 = 0) throws -> Message? {
        var buffer = UnsafeMutablePointer<Int8>.allocate(capacity: maxSize + 1)
        var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
        let addr = UnsafeMutablePointer<sockaddr>.allocate(capacity: MemoryLayout<sockaddr>.size)
        
        defer {
            buffer.deallocate()
            addr.deallocate()
        }
        
        let success = Darwin.recvfrom(
            fd,
            buffer,
            maxSize,
            flags,
            addr,
            &addrLen
        )
        guard success != -1 else {
            throw SocketError.systemCallError(errno, .recv)
        }
        
        if case .tcp = self.addressInfo.communicationProtocol, success == 0 {
            return nil // Connection is closed if TCP and success == 0.
        }
        buffer[success] = 0
        return Message(copy: buffer, length: success + 1, sender: addr.pointee)
    }
    
    public func recv(maxSize: Int, flags: Int32 = 0) throws -> Message? {
        var buffer = UnsafeMutablePointer<Int8>.allocate(capacity: maxSize + 1)
        var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
        let addr = UnsafeMutablePointer<sockaddr>.allocate(capacity: MemoryLayout<sockaddr>.size)
        
        defer {
            buffer.deallocate()
            addr.deallocate()
        }
        
        let success = Darwin.recvfrom(
            fd,
            buffer,
            maxSize,
            flags,
            addr,
            &addrLen
        )
        guard success != -1 else {
            throw SocketError.systemCallError(errno, .recv)
        }
        buffer[success] = 0
        return Message(copy: buffer, length: success + 1, sender: addr.pointee)
    }
    
    // TODO: Add a recv(msg: etc...) function.
}

extension Socket {
    /// Accepts a pending connection and returns the connected socket.
    /// 
    /// Before a socket is allowed to accept a connection, it must be bound
    /// to an address and a port, and must be listening for incomming 
    /// connections.
    /// 
    /// - Returns:
    ///					A connected socket, using the same protocol as the
    ///					calling bound socket.
    ///
    /// - Throws:
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`
    ///
    public func accept() throws -> Socket {
        let sockStorage = UnsafeMutablePointer<sockaddr_storage>.allocate(
            capacity: MemoryLayout<sockaddr_storage>.size
        )

        let success = sockStorage.withMemoryRebound(to: sockaddr.self, capacity: -1) { ptr -> Int32 in
            var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
            return Darwin.accept(fd, ptr, &length)
        }
        guard success != -1 else {
            throw SocketError.systemCallError(errno, .accept)
        }
        
        let socket = Socket(address: self.addressInfo, fd: success)
        socket.addressInfo.address.contents = sockStorage.pointee
        
        return socket
    }
    /// Instructs the socket to listen for incomming connections.
    ///
    /// - parameter backlog: The number of connections to queue before
    ///                         successive clients will be blocked.
    ///
    /// - Throws:
    ///     Errors are thrown when a system call fails, and are wrapped in the
    ///     error type `SocketError`
    ///
    /// - Seealso: [Man Pages](x-man-page://2/listen)
    ///
    public func listen(_ backlog: Int32) throws {
        guard backlog >= 0 else {
            throw SocketError.parameter("backlog must be >= 0", .listen)
        }
        guard Darwin.listen(
            fd,
            backlog
            ) == 0 else {
                throw SocketError.systemCallError(errno, .listen)
        }
    }
}

extension Socket {
    /// Sets whether the system is allowed to reuse the address if it's
    /// already in use.
    /// 
    /// - Note:
    /// If 'bind' fails because the 'address is already in use' then setting
    /// this option to `true` will allow the address to be reused. This scenario
    /// occurs when the a connection on the same address is still lingering.
    /// It is especially useful during testing as it removes unnessesary time
    /// between runs.
    ///
    ///	- parameter value:	`true` to allow reuse of the address, `false` to 
    ///						disallow reuse of the address.
    ///
    /// - Throws:
    ///     Errors are thrown when a system call fails, and are wrapped in the
    ///     error type `SocketError`
    ///
    public func setShouldReuseAddress(_ value: Bool) throws {
        var number: CInt = value ? 1 : 0
        guard Darwin.setsockopt(
            fd,
            SOL_SOCKET,
            SO_REUSEADDR,
            &number,
            socklen_t(MemoryLayout<CInt>.size)
            ) != -1 else {
                throw SocketError.systemCallError(errno, .setOption)
        }
        // OS X requires an additional call. 
        // See http://stackoverflow.com/questions/4766072/address-already-in-use-im-misunderstanding-udp
        guard Darwin.setsockopt(
            fd,
            SOL_SOCKET,
            SO_REUSEPORT,
            &number,
            socklen_t(MemoryLayout<CInt>.size)
            ) != -1 else {
                throw SocketError.systemCallError(errno, .setOption)
        }
    }
    
    /// Sets the specified socket option.
    ///
    /// See [the man pages](x-man-page://2/setsockopt) for more details.
    ///
    /// - parameters:
    ///     - layer:        The layer which the option is to be interpreted for.
    ///                     Default is `SOL_SOCKET`.
    ///     - option:       The specified option to set.
    ///     - value:        The value of the option.
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`
    ///
    public func setSocketOption(_ layer: Int32 = SOL_SOCKET, option: Int32,
                                value: UnsafeRawPointer, valueLen: socklen_t) throws {
        guard Darwin.setsockopt(
            fd,
            layer,
            option,
            value,
            valueLen
            ) == 0 else {
                throw SocketError.systemCallError(errno, .setOption)
        }
    }
    /// Gets the specified socket option.
    ///
    /// See [the man pages](x-man-page://2/getsockopt) for more details.
    ///
    /// - parameters:
    ///     - layer:        The layer which the option is to be interpreted for.
    ///                     Default is `SOL_SOCKET`.
    ///     - option:       The specified option to get.
    ///     - value:        A buffer which will be filled with the result.
    ///     - valueLen:     The length of the buffer.
    ///
    /// - Throws: 
    ///     Errors are thrown when a system call fails, and are wrapped in the 
    ///     error type `SocketError`
    ///
    public func getSocketOption(_ layer: Int32 = SOL_SOCKET, option: Int32,
                                value: UnsafeMutableRawPointer, valueLen: inout socklen_t) throws {
        guard Darwin.getsockopt(
            fd,
            layer,
            option,
            value,
            &valueLen
            ) == 0 else {
                throw SocketError.systemCallError(errno, .getOption)
        }
    }
}

extension Socket : Equatable { }
public func ==(lhs: Socket, rhs: Socket) -> Bool {
    return lhs.fd == rhs.fd
}

extension sockaddr_un {
    /// Copies `path` into `sun_path`. Values located over the 104th index are
    /// not copied.
    mutating func setPath(_ path: UnsafePointer<Int8>, length: Int) {
        
        var array = ContiguousArray<Int8>(repeating: 0, count: 104)
        for i in 0..<length {
            array[i] = path[i]
        }
        setPath(array)
    }
    
    /// Copies a `path` into `sun_path`
    /// - Warning: Path must be at least 104 in length.
    mutating func setPath(_ path: ContiguousArray<Int8>) {
        
        precondition(path.count >= 104, "Path must be at least 104 in length")
        
        sun_path.0 = path[0]
        // and so on for infinity ...
        // ... python is handy
        sun_path.1 = path[1]
        sun_path.2 = path[2]
        sun_path.3 = path[3]
        sun_path.4 = path[4]
        sun_path.5 = path[5]
        sun_path.6 = path[6]
        sun_path.7 = path[7]
        sun_path.8 = path[8]
        sun_path.9 = path[9]
        sun_path.10 = path[10]
        sun_path.11 = path[11]
        sun_path.12 = path[12]
        sun_path.13 = path[13]
        sun_path.14 = path[14]
        sun_path.15 = path[15]
        sun_path.16 = path[16]
        sun_path.17 = path[17]
        sun_path.18 = path[18]
        sun_path.19 = path[19]
        sun_path.20 = path[20]
        sun_path.21 = path[21]
        sun_path.22 = path[22]
        sun_path.23 = path[23]
        sun_path.24 = path[24]
        sun_path.25 = path[25]
        sun_path.26 = path[26]
        sun_path.27 = path[27]
        sun_path.28 = path[28]
        sun_path.29 = path[29]
        sun_path.30 = path[30]
        sun_path.31 = path[31]
        sun_path.32 = path[32]
        sun_path.33 = path[33]
        sun_path.34 = path[34]
        sun_path.35 = path[35]
        sun_path.36 = path[36]
        sun_path.37 = path[37]
        sun_path.38 = path[38]
        sun_path.39 = path[39]
        sun_path.40 = path[40]
        sun_path.41 = path[41]
        sun_path.42 = path[42]
        sun_path.43 = path[43]
        sun_path.44 = path[44]
        sun_path.45 = path[45]
        sun_path.46 = path[46]
        sun_path.47 = path[47]
        sun_path.48 = path[48]
        sun_path.49 = path[49]
        sun_path.50 = path[50]
        sun_path.51 = path[51]
        sun_path.52 = path[52]
        sun_path.53 = path[53]
        sun_path.54 = path[54]
        sun_path.55 = path[55]
        sun_path.56 = path[56]
        sun_path.57 = path[57]
        sun_path.58 = path[58]
        sun_path.59 = path[59]
        sun_path.60 = path[60]
        sun_path.61 = path[61]
        sun_path.62 = path[62]
        sun_path.63 = path[63]
        sun_path.64 = path[64]
        sun_path.65 = path[65]
        sun_path.66 = path[66]
        sun_path.67 = path[67]
        sun_path.68 = path[68]
        sun_path.69 = path[69]
        sun_path.70 = path[70]
        sun_path.71 = path[71]
        sun_path.72 = path[72]
        sun_path.73 = path[73]
        sun_path.74 = path[74]
        sun_path.75 = path[75]
        sun_path.76 = path[76]
        sun_path.77 = path[77]
        sun_path.78 = path[78]
        sun_path.79 = path[79]
        sun_path.80 = path[80]
        sun_path.81 = path[81]
        sun_path.82 = path[82]
        sun_path.83 = path[83]
        sun_path.84 = path[84]
        sun_path.85 = path[85]
        sun_path.86 = path[86]
        sun_path.87 = path[87]
        sun_path.88 = path[88]
        sun_path.89 = path[89]
        sun_path.90 = path[90]
        sun_path.91 = path[91]
        sun_path.92 = path[92]
        sun_path.93 = path[93]
        sun_path.94 = path[94]
        sun_path.95 = path[95]
        sun_path.96 = path[96]
        sun_path.97 = path[97]
        sun_path.98 = path[98]
        sun_path.99 = path[99]
        sun_path.100 = path[100]
        sun_path.101 = path[101]
        sun_path.102 = path[102]
        sun_path.103 = path[103]
    }
    // Retrieves `sun_path` into an arary.
    func getPath() -> ContiguousArray<Int8> {
        var path = ContiguousArray<Int8>(repeating: 0, count: 104)

        path[0] = sun_path.0
        path[1] = sun_path.1
        path[2] = sun_path.2
        path[3] = sun_path.3
        path[4] = sun_path.4
        path[5] = sun_path.5
        path[6] = sun_path.6
        path[7] = sun_path.7
        path[8] = sun_path.8
        path[9] = sun_path.9
        path[10] = sun_path.10
        path[11] = sun_path.11
        path[12] = sun_path.12
        path[13] = sun_path.13
        path[14] = sun_path.14
        path[15] = sun_path.15
        path[16] = sun_path.16
        path[17] = sun_path.17
        path[18] = sun_path.18
        path[19] = sun_path.19
        path[20] = sun_path.20
        path[21] = sun_path.21
        path[22] = sun_path.22
        path[23] = sun_path.23
        path[24] = sun_path.24
        path[25] = sun_path.25
        path[26] = sun_path.26
        path[27] = sun_path.27
        path[28] = sun_path.28
        path[29] = sun_path.29
        path[30] = sun_path.30
        path[31] = sun_path.31
        path[32] = sun_path.32
        path[33] = sun_path.33
        path[34] = sun_path.34
        path[35] = sun_path.35
        path[36] = sun_path.36
        path[37] = sun_path.37
        path[38] = sun_path.38
        path[39] = sun_path.39
        path[40] = sun_path.40
        path[41] = sun_path.41
        path[42] = sun_path.42
        path[43] = sun_path.43
        path[44] = sun_path.44
        path[45] = sun_path.45
        path[46] = sun_path.46
        path[47] = sun_path.47
        path[48] = sun_path.48
        path[49] = sun_path.49
        path[50] = sun_path.50
        path[51] = sun_path.51
        path[52] = sun_path.52
        path[53] = sun_path.53
        path[54] = sun_path.54
        path[55] = sun_path.55
        path[56] = sun_path.56
        path[57] = sun_path.57
        path[58] = sun_path.58
        path[59] = sun_path.59
        path[60] = sun_path.60
        path[61] = sun_path.61
        path[62] = sun_path.62
        path[63] = sun_path.63
        path[64] = sun_path.64
        path[65] = sun_path.65
        path[66] = sun_path.66
        path[67] = sun_path.67
        path[68] = sun_path.68
        path[69] = sun_path.69
        path[70] = sun_path.70
        path[71] = sun_path.71
        path[72] = sun_path.72
        path[73] = sun_path.73
        path[74] = sun_path.74
        path[75] = sun_path.75
        path[76] = sun_path.76
        path[77] = sun_path.77
        path[78] = sun_path.78
        path[79] = sun_path.79
        path[80] = sun_path.80
        path[81] = sun_path.81
        path[82] = sun_path.82
        path[83] = sun_path.83
        path[84] = sun_path.84
        path[85] = sun_path.85
        path[86] = sun_path.86
        path[87] = sun_path.87
        path[88] = sun_path.88
        path[89] = sun_path.89
        path[90] = sun_path.90
        path[91] = sun_path.91
        path[92] = sun_path.92
        path[93] = sun_path.93
        path[94] = sun_path.94
        path[95] = sun_path.95
        path[96] = sun_path.96
        path[97] = sun_path.97
        path[98] = sun_path.98
        path[99] = sun_path.99
        path[100] = sun_path.100
        path[101] = sun_path.101
        path[102] = sun_path.102
        path[103] = sun_path.103
        
        return path
    }
}


// end of file
