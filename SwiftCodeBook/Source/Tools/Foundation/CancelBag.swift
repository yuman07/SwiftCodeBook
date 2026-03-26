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
        var allTokens = tokens.withLockUnchecked { tokens in
            let copy = tokens
            tokens.removeAll()
            return copy
        }
        allTokens.removeAll()
    }
    
    public func store(_ cancelToken: AnyCancellable) {
        tokens.withLockUnchecked { tokens in
            cancelToken.store(in: &tokens)
        }
    }
    
    public func cancelAll() {
        let allTokens = tokens.withLockUnchecked { tokens in
            let copy = tokens
            tokens.removeAll()
            return copy
        }
        for token in allTokens { token.cancel() }
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.store(self)
    }
}
