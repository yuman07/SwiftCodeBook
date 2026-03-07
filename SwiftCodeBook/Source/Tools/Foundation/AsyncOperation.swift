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
        case ready = "isReady"
        case executing = "isExecuting"
        case finished = "isFinished"
    }
    
    private let _state = OSAllocatedUnfairLock(initialState: State.ready)
    private var state: State {
        get { _state.withLock { $0 } }
        set {
            guard case let oldValue = state, oldValue != newValue else { return }
            willChangeValue(forKey: oldValue.rawValue)
            willChangeValue(forKey: newValue.rawValue)
            _state.withLock { $0 = newValue }
            didChangeValue(forKey: newValue.rawValue)
            didChangeValue(forKey: oldValue.rawValue)
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
    
    public final override func start() {
        state = .executing
    }
    
    public final func finish() {
        state = .finished
    }
    
    open override func main() {
        fatalError("Subclasses must implement main() and call finish() when done.")
    }
}
