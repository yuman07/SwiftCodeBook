//
//  AsyncOperation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/20.
//

import Foundation
import os

open class AsyncOperation: Operation, @unchecked Sendable {
    private enum State: String {
        case ready
        case executing
        case finished
        var keyPath: String {
            "is" + rawValue.capitalized
        }
    }

    private let _state = OSAllocatedUnfairLock(initialState: State.ready)
    private var state: State {
        get { _state.withLock { $0 } }
        set {
            guard case let oldValue = state, oldValue != newValue else { return }
            willChangeValue(forKey: oldValue.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            _state.withLock { $0 = newValue }
            didChangeValue(forKey: newValue.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    public final override var isAsynchronous: Bool {
        true
    }

    public final override var isReady: Bool {
        super.isReady && state == .ready
    }

    public final override var isExecuting: Bool {
        state == .executing
    }

    public final override var isFinished: Bool {
        state == .finished
    }
    
    public final override func cancel() {
        super.cancel()
    }
    
    public final func finish() {
        state = .finished
    }

    open override func start() {
        fatalError("Subclasses must implement start() and call finish() when done.")
    }
}
