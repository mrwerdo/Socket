//
//  Select.swift
//  SocketsDev
//
//  Created by Andrew Thompson on 17/01/2016.
//  Copyright © 2016 Andrew Thompson. All rights reserved.
//

import Darwin

private let __DARWIN_NFDBITS = Int32(sizeof(Int32)) * __DARWIN_NBBY
private let __DARWIN_NUMBER_OF_BITS_IN_SET: Int32 = { () -> Int32 in
    func howmany(_ x: Int32, _ y: Int32) -> Int32 {
        return (x % y) == 0 ? (x / y) : (x / (y + 1))
    }
    return howmany(__DARWIN_FD_SETSIZE, __DARWIN_NFDBITS)
}()
extension fd_set {
    
    /// Returns the index of the highest bit set.
    private mutating func highestDescriptor() -> Int32 {
        var highestFD: Int32 = 0
        let max = (__DARWIN_NUMBER_OF_BITS_IN_SET * Int32(sizeof(__int32_t)) - 1)
        let min: Int32 = 0
        
        for index in stride(from: max, through: min, by: -1) {
            if isset(index) != 0 {
                highestFD = index
                break
            }
        }
        return highestFD
    }
    
    /// Clears the `bit` index given.
    private mutating func clear(_ bit: Int32) {
        let i = Int(bit / __DARWIN_NFDBITS)
        let v = ~Int32(1 << (bit % __DARWIN_NFDBITS))
        
        let array = unsafeAddressOfCObj(&self.fds_bits.0)
        array[i] &= v
    }
    /// Sets the `bit` index given.
    private mutating func set(_ bit: Int32) {
        let i = Int(bit / __DARWIN_NFDBITS)
        let v = Int32(1 << (bit % __DARWIN_NFDBITS))
        
        let array = unsafeAddressOfCObj(&self.fds_bits.0)
        array[i] |= v
    }
    /// Returns non-zero if `bit` is set.
    private mutating func isset(_ bit: Int32) -> Int32 {
        let i = Int(bit / __DARWIN_NFDBITS)
        let v = Int32(1 << (bit % __DARWIN_NFDBITS))
        
        let array = unsafeAddressOfCObj(&self.fds_bits.0)
        return array[i] & v
    }
    /// Zeros `self`, so no bits are set.
    public mutating func zero() {
        let bits = unsafeAddressOfCObj(&self.fds_bits.0)
        bzero(bits, Int(__DARWIN_NUMBER_OF_BITS_IN_SET))
    }
    /// Returns `true` if `socket` is in the set.
    public mutating func isSet(_ socket: Socket) -> Bool {
        return isset(socket.fd) != 0
    }
    /// Adds `socket` to the set.
    public mutating func add(_ socket: Socket) {
        self.set(socket.fd)
    }
    /// Removes `socket` from the set.
    public mutating func remove(_ socket: Socket) {
        self.clear(socket.fd)
    }
}

/// Waits efficiently until a file descriptor(s) specified is marked as having
/// either pending data, a penidng error, or the ability to write. 
///
/// Any file descriptor's added to `read` will cause `select` to observer their
/// status until one or more has any pending data available to read. This is 
/// similar for `write` and `error` too - `select` will return once some file
/// descriptors have been flagged for writing or have an error pending.
///
/// The `timeout` parameter will cause `select` to wait for the specified time,
/// then return, if no file descriptors have changed state. If a file descriptor
/// has changed its state, then select will return immediately and mark the file
/// descriptors accordingly.
///
/// - parameters:
///     - read:         Contains a set of file descriptors which have pending 
///                     data ready to be read.
///     - write:        Contains any file descriptors which can be immediately
///                     written to.
///     - error:        Contains any file descriptors which have a pending error
///                     on them.
///     - timeout:      Contains the timeout period `select` will wait until
///                     returning if no changes are observed on the file 
///                     descriptor.
/// - Returns:
///                     The number of file descriptors who's status' have been
///                     changed. Select modifies the given sets to contain only
///                     a subset of those given, which have had their status'
///                     changed. If you pass nil to either `read`, `write` or
///                     `error`, then you will recieve nil out the other end.
/// - Throws:
///     - `SocketError.SelectFailed`
public func select(read: fd_set?, write: fd_set?, error: fd_set?, timeout: UnsafeMutablePointer<timeval>) throws -> (numberChanged: Int32, read: fd_set!, write: fd_set!, error: fd_set!) {
    
    var read_out = read
    var write_out = write
    var error_out = error
    
    var highestFD: Int32 = 0
    highestFD = read_out?.highestDescriptor() ?? highestFD
    highestFD = write_out?.highestDescriptor() ?? highestFD
    highestFD = error_out?.highestDescriptor() ?? highestFD
    
    
    let rptr = read_out != nil ? unsafeAddressOfCObj(&(read_out!)) : UnsafeMutablePointer(nil)
    let wptr = write_out != nil ? unsafeAddressOfCObj(&(write_out!)) : UnsafeMutablePointer(nil)
    let eptr = error_out != nil ? unsafeAddressOfCObj(&(error_out!)) : UnsafeMutablePointer(nil)
    
    let result = Darwin.select(
        highestFD + 1,
        rptr,
        wptr,
        eptr,
        timeout
    )
    
    guard result != -1 else {
        throw SocketError.SelectFailed(errno)
    }
    return (result, read_out, write_out, error_out)
}

