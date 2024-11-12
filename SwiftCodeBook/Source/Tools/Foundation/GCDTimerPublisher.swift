//
//  GCDTimerPublisher.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/12.
//

import Combine
import Foundation
import os

// https://github.com/OpenCombine/OpenCombine/blob/master/Sources/OpenCombineFoundation/Timer%2BPublisher.swift
public extension GCDTimer {
    static func publish(every: TimeInterval, receiveQueue: DispatchQueue = .main) -> GCDTimerPublisher {
        GCDTimerPublisher(interval: every, receiveQueue: receiveQueue)
    }
}

public final class GCDTimerPublisher: ConnectablePublisher {
    public typealias Output = Int
    public typealias Failure = Never
    
    private let interval: TimeInterval
    private let receiveQueue: DispatchQueue
    private let timer = OSAllocatedUnfairLock<GCDTimer?>(initialState: nil)
    private let sides = OSAllocatedUnfairLock(initialState: [CombineIdentifier: Side]())
    
    init(interval: TimeInterval, receiveQueue: DispatchQueue = .main) {
        self.interval = interval
        self.receiveQueue = receiveQueue
    }
    
    public func connect() -> any Cancellable {
        timer.withLock { timer in
            timer = GCDTimer(timeInterval: interval, repeats: true, queue: receiveQueue, block: { [weak self] _ in
                guard let self else { return }
                sides.withLock { sides in
                    for side in sides.values {
                        side.send(side.count)
                        side.count += 1
                    }
                }
            })
            timer?.start()
        }
        return AnyCancellable { [weak self] in
            guard let self else { return }
            sides.withLock { sides in
                sides = [:]
            }
            timer.withLock { timer in
                timer = nil
            }
        }
    }
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream) where Failure == Downstream.Failure, Output == Downstream.Input {
        sides.withLock { sides in
            let inner = Inner(parent: self, downstream: subscriber)
            sides[inner.combineIdentifier] = Side(count: 0, send: inner.send(_:))
            subscriber.receive(subscription: inner)
        }
    }
    
    private func disconnect(_ innerID: CombineIdentifier) {
        sides.withLock { sides in
            sides[innerID] = nil
        }
    }
    
    private final class Side {
        var count: Output
        let send: (Output) -> Void

        init(count: Output, send: @escaping (Output) -> Void) {
            self.count = count
            self.send = send
        }
    }
    
    private final class Inner<Downstream: Subscriber>: Subscription where Downstream.Input == Output, Downstream.Failure == Never {
        private weak var parent: GCDTimerPublisher?
        private var downstream: Downstream?
        private var pending = Subscribers.Demand.none
        private let lock = OSAllocatedUnfairLock()
        
        init(parent: GCDTimerPublisher, downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        func send(_ value: Output) {
            lock.withLock {
                guard let downstream, pending != .none else { return }
                pending -= 1
                let newDemand = downstream.receive(value)
                guard newDemand != .none else { return }
                pending += newDemand
            }
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.withLock {
                guard downstream != nil else { return }
                pending += demand
            }
        }
        
        func cancel() {
            lock.withLock {
                guard downstream != nil else { return }
                downstream = nil
                parent?.disconnect(combineIdentifier)
            }
        }
    }
}
