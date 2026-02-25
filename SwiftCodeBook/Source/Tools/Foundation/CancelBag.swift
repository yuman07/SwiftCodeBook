//
//  CancelBag.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/24.
//
 
import Combine
import Foundation
import os

public final class CancelBag: Sendable {
    private let tokens = OSAllocatedUnfairLock(uncheckedState: Set<AnyCancellable>())
    
    public init() {}
    
    deinit {
        tokens.withLock { tokens in
            tokens.removeAll()
        }
    }
    
    public func store(_ cancelToken: AnyCancellable) {
        tokens.withLockUnchecked { tokens in
            cancelToken.store(in: &tokens)
        }
    }
    
    public func cancelAll() {
        tokens.withLock { tokens in
            for token in tokens { token.cancel() }
            tokens.removeAll()
        }
    }
    
    public func cancel(_ cancelToken: AnyCancellable) {
        tokens.withLockUnchecked { tokens in
            tokens.remove(cancelToken)
            cancelToken.cancel()
        }
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.store(self)
    }
}
