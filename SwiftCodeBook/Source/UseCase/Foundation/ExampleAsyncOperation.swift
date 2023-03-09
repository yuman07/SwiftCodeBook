//
//  ExampleAsyncOperation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/20.
//

import Foundation

final class ExampleAsyncOperation: Operation {
    private struct AssociatedKeys {
        static var isExecuting = "isExecuting"
        static var isFinished = "isFinished"
        static var isCancelled = "isCancelled"
    }
    
    private let lock = NSRecursiveLock()
    
    private let requestKey: String
    private let finishBlock: (Result<String, Error>) -> Void
    private var result = ""
    
    init(requestKey: String, finishBlock: @escaping (Result<String, Error>) -> Void) {
        self.requestKey = requestKey
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
    
    override private(set) var isExecuting: Bool {
        get {
            lock.withLock { (objc_getAssociatedObject(self, &AssociatedKeys.isExecuting) as? Bool) ?? false }
        }
        set {
            willChangeValue(forKey: AssociatedKeys.isExecuting)
            lock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.isExecuting, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            didChangeValue(forKey: AssociatedKeys.isExecuting)
        }
    }
    
    override private(set) var isFinished: Bool {
        get {
            lock.withLock { (objc_getAssociatedObject(self, &AssociatedKeys.isFinished) as? Bool) ?? false }
        }
        set {
            willChangeValue(forKey: AssociatedKeys.isFinished)
            lock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.isFinished, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            didChangeValue(forKey: AssociatedKeys.isFinished)
        }
    }
    
    override private(set) var isCancelled: Bool {
        get { lock.withLock { (objc_getAssociatedObject(self, &AssociatedKeys.isCancelled) as? Bool) ?? false } }
        set { lock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.isCancelled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) } }
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
            
            self.result = "\(self.requestKey) + \(UUID().uuidString)"
            self.complete()
        }
    }
}
