//
//  Select.swift
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

//private let __DARWIN_NFDBITS = Int32(sizeof(Int32)) * __DARWIN_NBBY
//private let __DARWIN_NUMBER_OF_BITS_IN_SET: Int32 = { () -> Int32 in
//    func howmany(x: Int32, _ y: Int32) -> Int32 {
//        return (x % y) == 0 ? (x / y) : (x / (y + 1))
//    }
//    return howmany(__DARWIN_FD_SETSIZE, __DARWIN_NFDBITS)
//}()
extension fd_set {
    
    /// Returns the index of the highest bit set.
    fileprivate func highestDescriptor() -> Int32 {
        return qs_fd_highest_fd(self)
    }
    
    /// Clears the `bit` index given.
    public mutating func clear(_ fd: Int32) {
        qs_fd_clear(&self, fd)
    }
    /// Sets the `bit` index given.
    public mutating func set(_ fd: Int32) {
        qs_fd_set(&self, fd)
    }
    /// Returns non-zero if `bit` is set.
    public func isset(_ fd: Int32) -> Bool {
        return qs_fd_isset(self, fd) != 0
    }
    /// Zeros `self`, so no bits are set.
    public mutating func zero() {
        qs_fd_zero(&self)
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
///                     `error`, then you will receive nil out the other end.
/// - Throws:
///     - `SocketError.SelectFailed`
public func select(read: UnsafeMutablePointer<fd_set>?, write: UnsafeMutablePointer<fd_set>?, error: UnsafeMutablePointer<fd_set>?, timeout: UnsafeMutablePointer<timeval>?) throws -> Int32 {
    
    var highestFD: Int32 = 0
    if let k = read?.pointee.highestDescriptor() {
        if k > highestFD {
            highestFD = k
        }
    }
    if let k = write?.pointee.highestDescriptor() {
        if k > highestFD {
            highestFD = k
        }
    }
    if let k = error?.pointee.highestDescriptor() {
        if k > highestFD {
            highestFD = k
        }
    }
    let result = select(highestFD, read, write, error, timeout)
    guard result != -1 else {
        throw SocketError.systemCallError(errno, .select)
    }
    return result
}

enum CError : Error {
    case cError(Int32)
}


public func pipe() throws -> (readfd: Int32, writefd: Int32) {
    var fds: [Int32] = [-1, -1]
    guard pipe(&fds) == 0 else {
        throw CError.cError(errno)
    }
    guard fds[0] > -1 && fds[1] > -1 else {
        fatalError("file descriptors are invalid and pipe failed to report an error!")
    }
    return (fds[0], fds[1])
}

