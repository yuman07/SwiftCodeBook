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
        tokens.withLock { set in
            set.removeAll()
        }
    }
    
    public func store(_ cancelToken: AnyCancellable) {
        tokens.withLockUnchecked { set in
            cancelToken.store(in: &set)
        }
    }
    
    public func cancelAll() {
        tokens.withLock { set in
            for token in set { token.cancel() }
            set.removeAll()
        }
    }
    
    public func cancel(_ cancelToken: AnyCancellable) {
        tokens.withLockUnchecked { set in
            set.remove(cancelToken)
            cancelToken.cancel()
        }
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.store(self)
    }
}
