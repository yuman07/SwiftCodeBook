//
//  CancelBag.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/24.
//

import Combine
import Foundation

public final class CancelBag {
    private let lock = NSLock()
    private var tokens = Set<AnyCancellable>()
    
    public init() {}
    
    deinit {
        lock.lock()
        defer { lock.unlock() }
        tokens.removeAll()
    }
    
    public func store(_ cancellable: AnyCancellable) {
        lock.lock()
        defer { lock.unlock() }
        cancellable.store(in: &tokens)
    }
    
    public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        for token in tokens { token.cancel() }
        tokens.removeAll()
    }
}

public extension AnyCancellable {
    func store(in cancelBag: CancelBag) {
        cancelBag.store(self)
    }
}
