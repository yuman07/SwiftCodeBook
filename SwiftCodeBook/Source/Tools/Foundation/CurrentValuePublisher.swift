//
//  CurrentValuePublisher.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/29.
//

import Combine
import Foundation

/// Declares a type that can transmit a sequence of values over time, and
/// always has a current value.
public protocol CurrentValuePublisher: Publisher {
    /// The current value of this publisher.
    var value: Output { get }
}

// MARK: Conforming Types

extension CurrentValueSubject: CurrentValuePublisher {}
extension Just: CurrentValuePublisher {}
extension Published.Publisher: CurrentValuePublisher {}
extension NSObject.KeyValueObservingPublisher: CurrentValuePublisher {}

// MARK: Public

extension CurrentValuePublisher where Failure == Never {
    @inlinable
    public var value: Output {
        return _getValue()
    }
}

public extension CurrentValuePublisher {
    func eraseToAnyCurrentValuePublisher() -> AnyCurrentValuePublisher<Output, Failure> {
        AnyCurrentValuePublisher(self)
    }
}

// MARK: Internal

extension Publisher {
    /// Subscribes and synchronously returns the first value output from this
    /// publisher.
    ///
    /// - Warning: Must only be called on a `CurrentValuePublisher`, otherwise
    ///   this will unconditionally trap.
    @usableFromInline
    func _getValue() -> Output {
        var value: Output!
        _ = first().sink(
            receiveCompletion: { _ in },
            receiveValue: { value = $0 }
        )
        return value
    }
}

/// A publisher that wraps an upstream `CurrentValuePublisher`, transforming
/// its current value and all values published by it.
public final class AnyCurrentValuePublisher<Value, Failure: Error>: CurrentValuePublisher {
    public typealias Output = Value
    
    private let _publisher: AnyPublisher<Value, Failure>
    private let _value: () -> Value
    
    public convenience init<Root: CurrentValuePublisher>(
        _ subject: Root,
        _ transform: @escaping (Root.Output) -> Value
    ) where Root.Failure == Failure {
        self.init(
            unsafeSubject: subject,
            value: { transform(subject.value) },
            transform: transform
        )
    }
    
    public convenience init<Root: CurrentValuePublisher>(
        _ subject: Root,
        keyPath: KeyPath<Root.Output, Value>
    ) where Root.Failure == Failure {
        self.init(
            unsafeSubject: subject,
            value: { subject.value[keyPath: keyPath] },
            transform: { $0[keyPath: keyPath] }
        )
    }
    
    public convenience init<Root: CurrentValuePublisher>(
        _ subject: Root
    ) where Root.Output == Output, Root.Failure == Failure {
        self.init(
            unsafeSubject: subject,
            value: { subject.value }
        )
    }
    
    public init<P: Publisher>(
        unsafeSubject subject: P,
        value: @escaping () -> Value,
        transform: @escaping (P.Output) -> Value
    ) where P.Failure == Failure {
        self._value = value
        self._publisher = subject.map(transform).eraseToAnyPublisher()
    }
    
    public init<P: Publisher>(
        unsafeSubject subject: P,
        value: @escaping () -> Value
    ) where P.Output == Output, P.Failure == Failure {
        self._value = value
        self._publisher = subject.eraseToAnyPublisher()
    }
    
    public var value: Value {
        _value()
    }
    
    public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Value {
        _publisher.receive(subscriber: subscriber)
    }
}
