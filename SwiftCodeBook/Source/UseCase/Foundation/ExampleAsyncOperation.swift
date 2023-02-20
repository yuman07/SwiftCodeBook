//
//  ExampleAsyncOperation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/20.
//

import Foundation

final class ExampleAsyncOperation: Operation {
    private let lock = NSRecursiveLock()
    
    private var result = ""
    private let finishBlock: (Result<String, Error>) -> Void
    
    init(finishBlock: @escaping (Result<String, Error>) -> Void) {
        self.finishBlock = finishBlock
    }
    
    override func start() {
        completionBlock = { [weak self] in
            guard let self else { return }
            guard !self.isCancelled else { return self.finishBlock(.failure(CancellationError())) }
            self.finishBlock(.success(self.result))
        }
        
        guard !isCancelled else { return complete() }
        
        isExecuting = true
        main()
    }
    
    private var _isExecuting: Bool = false
    override private(set) var isExecuting: Bool {
        get {
            lock.withLock { _isExecuting }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lock.withLock { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished: Bool = false
    override private(set) var isFinished: Bool {
        get {
            lock.withLock { _isFinished }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lock.withLock { _isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    private var _isCancelled: Bool = false
    override private(set) var isCancelled: Bool {
        get {
            lock.withLock { _isCancelled }
        }
        set {
            lock.withLock { _isCancelled = newValue }
        }
    }
    
    override func cancel() {
        lock.withLock {
            super.cancel()
            isCancelled = true
        }
    }
    
    override var isAsynchronous: Bool {
        true
    }
    
    private func complete() {
        lock.withLock {
            isExecuting = false
            isFinished = true
        }
    }
    
    override func main() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            guard !self.isCancelled else { return self.complete() }
            
            self.result = "result + \(UUID().uuidString)"
            self.complete()
        }
    }
}
