//
//  ExampleAsyncOperation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/20.
//

import Foundation

final class ExampleAsyncOperation: Operation {
    private enum AssociatedKeys {
        static var isExecuting: Void?
        static var isFinished: Void?
        static var isCancelled: Void?
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
            guard !isCancelled else { return finishBlock(.failure(CancellationError())) }
            finishBlock(.success(result))
        }
        
        guard !isCancelled else { return complete() }
        
        isExecuting = true
        main()
    }
    
    override private(set) var isExecuting: Bool {
        get { lock.withLock { objc_getAssociatedObject(self, &AssociatedKeys.isExecuting) as? Bool ?? false } }
        set {
            willChangeValue(forKey: "isExecuting")
            lock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.isExecuting, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override private(set) var isFinished: Bool {
        get { lock.withLock { objc_getAssociatedObject(self, &AssociatedKeys.isFinished) as? Bool ?? false } }
        set {
            willChangeValue(forKey: "isFinished")
            lock.withLock { objc_setAssociatedObject(self, &AssociatedKeys.isFinished, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override private(set) var isCancelled: Bool {
        get { lock.withLock { objc_getAssociatedObject(self, &AssociatedKeys.isCancelled) as? Bool ?? false } }
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
            guard !isCancelled else { return complete() }
            
            result = "\(requestKey) + \(UUID().uuidString)"
            complete()
        }
    }
}
