//
//  ReadWriteLock.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

final class ReadWriteLock {
    private var lock = pthread_rwlock_t()
    
    init() {
        pthread_rwlock_init(&lock, nil)
    }
    
    deinit {
        pthread_rwlock_destroy(&lock)
    }
    
    func lockRead() {
        pthread_rwlock_rdlock(&lock)
    }
    
    func lockWrite() {
        pthread_rwlock_wrlock(&lock)
    }
    
    func unlock() {
        pthread_rwlock_unlock(&lock)
    }
}

extension ReadWriteLock {
    func read(_ block: () throws -> Void) rethrows {
        lockRead()
        defer { unlock() }
        try block()
    }
    
    func read<T>(_ block: () throws -> T) rethrows -> T {
        lockRead()
        defer { unlock() }
        return try block()
    }
    
    func write(_ block: () throws -> Void) rethrows {
        lockWrite()
        defer { unlock() }
        try block()
    }
    
    func write<T>(_ block: () throws -> T) rethrows -> T {
        lockWrite()
        defer { unlock() }
        return try block()
    }
}
