//
//  File.swift
//  
//
//  Created by Pathao Ltd on 31/12/24.
//

import Darwin


/// A threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_mutex_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
internal final class Lock: @unchecked Sendable {
    
    fileprivate let mutex: UnsafeMutablePointer<pthread_mutex_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
   
    /// Create a new lock.
    public init() {
      
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))

        let err = pthread_mutex_init(self.mutex, &attr)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")

    }

    deinit {
       
        let err = pthread_mutex_destroy(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
        self.mutex.deallocate()
       
    }

    /// Acquire the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `unlock`, to simplify lock handling.
    public func lock() {
       
        let err = pthread_mutex_lock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
       
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withLock` instead of this method and
    /// `lock`, to simplify lock handling.
    public func unlock() {
        
        let err = pthread_mutex_unlock(self.mutex)
        precondition(err == 0, "\(#function) failed in pthread_mutex with error \(err)")
       
    }
}

extension Lock {
    /// Acquire the lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lock` and `unlock` in
    /// most situations, as it ensures that the lock will be released regardless
    /// of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the lock.
    /// - Returns: The value returned by the block.
    @inlinable
    internal func withLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lock()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withLockVoid(_ body: () throws -> Void) rethrows {
        try self.withLock(body)
    }
}

/// A reader/writer threading lock based on `libpthread` instead of `libdispatch`.
///
/// This object provides a lock on top of a single `pthread_rwlock_t`. This kind
/// of lock is safe to use with `libpthread`-based threading models, such as the
/// one used by NIO. On Windows, the lock is based on the substantially similar
/// `SRWLOCK` type.
internal final class ReadWriteLock: @unchecked Sendable {
   
    fileprivate let rwlock: UnsafeMutablePointer<pthread_rwlock_t> =
        UnsafeMutablePointer.allocate(capacity: 1)
   
    /// Create a new lock.
    public init() {
       
        let err = pthread_rwlock_init(self.rwlock, nil)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
       
    }

    deinit {
       
        let err = pthread_rwlock_destroy(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        self.rwlock.deallocate()
        
    }

    /// Acquire a reader lock.
    ///
    /// Whenever possible, consider using `withReaderLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    fileprivate func lockRead() {
       
        let err = pthread_rwlock_rdlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
        
    }

    /// Acquire a writer lock.
    ///
    /// Whenever possible, consider using `withWriterLock` instead of this
    /// method and `unlock`, to simplify lock handling.
    fileprivate func lockWrite() {
       
        let err = pthread_rwlock_wrlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
       
    }

    /// Release the lock.
    ///
    /// Whenever possible, consider using `withReaderLock` and `withWriterLock`
    /// instead of this method and `lockRead` and `lockWrite`, to simplify lock
    /// handling.
    fileprivate func unlock() {
       
        let err = pthread_rwlock_unlock(self.rwlock)
        precondition(err == 0, "\(#function) failed in pthread_rwlock with error \(err)")
       
    }
}

extension ReadWriteLock {
    /// Acquire the reader lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockRead` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the reader lock.
    /// - Returns: The value returned by the block.
    @inlinable
    internal func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockRead()
        defer {
            self.unlock()
        }
        return try body()
    }

    /// Acquire the writer lock for the duration of the given block.
    ///
    /// This convenience method should be preferred to `lockWrite` and `unlock`
    /// in most situations, as it ensures that the lock will be released
    /// regardless of how `body` exits.
    ///
    /// - Parameter body: The block to execute while holding the writer lock.
    /// - Returns: The value returned by the block.
    @inlinable
    internal func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
        self.lockWrite()
        defer {
            self.unlock()
        }
        return try body()
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withReaderLockVoid(_ body: () throws -> Void) rethrows {
        try self.withReaderLock(body)
    }

    // specialise Void return (for performance)
    @inlinable
    internal func withWriterLockVoid(_ body: () throws -> Void) rethrows {
        try self.withWriterLock(body)
    }
}

//import Foundation
//
///// A threading lock based on `NSLock`.
//internal final class Lock: @unchecked Sendable {
//    private let nsLock = NSLock()
//    
//    /// Create a new lock.
//    public init() {}
//
//    /// Acquire the lock.
//    public func acquireLock() {
//        nsLock.lock()
//    }
//
//    /// Release the lock.
//    public func unlock() {
//        nsLock.unlock()
//    }
//}
//
//extension Lock {
//    /// Acquire the lock for the duration of the given block.
//    ///
//    /// This convenience method should be preferred to `acquireLock` and `unlock` in
//    /// most situations, as it ensures that the lock will be released regardless
//    /// of how `body` exits.
//    ///
//    /// - Parameter body: The block to execute while holding the lock.
//    /// - Returns: The value returned by the block.
//    @inlinable
//    internal func withLock<T>(_ body: () throws -> T) rethrows -> T {
//        acquireLock()
//        defer { unlock() }
//        return try body()
//    }
//
//    /// Specialise Void return (for performance).
//    @inlinable
//    internal func withLockVoid(_ body: () throws -> Void) rethrows {
//        try withLock(body)
//    }
//}
//
//
//import Foundation
//
///// A reader/writer threading lock based on `DispatchQueue`.
//internal final class ReadWriteLock: @unchecked Sendable {
//    private let queue = DispatchQueue(label: "com.example.ReadWriteLock", attributes: .concurrent)
//
//    /// Acquire the reader lock for the duration of the given block.
//    ///
//    /// This convenience method should be preferred to explicit locking
//    /// whenever possible, as it ensures the lock is released appropriately.
//    ///
//    /// - Parameter body: The block to execute while holding the reader lock.
//    /// - Returns: The value returned by the block.
//    @inlinable
//    internal func withReaderLock<T>(_ body: () throws -> T) rethrows -> T {
//        try queue.sync {
//            try body()
//        }
//    }
//
//    /// Acquire the writer lock for the duration of the given block.
//    ///
//    /// This convenience method should be preferred to explicit locking
//    /// whenever possible, as it ensures the lock is released appropriately.
//    ///
//    /// - Parameter body: The block to execute while holding the writer lock.
//    /// - Returns: The value returned by the block.
//    @inlinable
//    internal func withWriterLock<T>(_ body: () throws -> T) rethrows -> T {
//        try queue.sync(flags: .barrier) {
//            try body()
//        }
//    }
//
//    /// Specialise Void return (for performance).
//    @inlinable
//    internal func withReaderLockVoid(_ body: () throws -> Void) rethrows {
//        try withReaderLock(body)
//    }
//
//    /// Specialise Void return (for performance).
//    @inlinable
//    internal func withWriterLockVoid(_ body: () throws -> Void) rethrows {
//        try withWriterLock(body)
//    }
//}
