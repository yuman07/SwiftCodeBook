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
    private let tokens = OSAllocatedUnfairLock(initialState: Set<AnyCancellable>())
    
    public init() {}
    
    deinit {
        cancel()
    }
    
    public func store(_ cancellable: AnyCancellable) {
        tokens.withLock { token in
            cancellable.store(in: &token)
        }
    }
    
    public func cancel() {
        tokens.withLock { tokens in
            for token in tokens { token.cancel() }
            tokens.removeAll()
        }
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.store(self)
    }
}
