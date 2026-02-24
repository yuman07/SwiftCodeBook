//
//  SendablePassthroughSubject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/24.
//

import Combine
import Foundation

public final class SendablePassthroughSubject<Output, Failure>: @unchecked Sendable where Failure: Error {
    private let lock = NSRecursiveLock()
    private let subject = PassthroughSubject<Output, Failure>()
    private let publisher: AnyPublisher<Output, Failure>
    
    public init() {
        self.publisher = subject.eraseToAnyPublisher()
    }
    
    public func send(_ input: Output) {
        lock.withLock {
            subject.send(input)
        }
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        lock.withLock {
            subject.send(completion: completion)
        }
    }
    
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> {
        publisher
    }
}
