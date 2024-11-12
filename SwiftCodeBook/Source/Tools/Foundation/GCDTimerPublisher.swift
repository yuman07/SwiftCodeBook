//
//  GCDTimerPublisher.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/12.
//

import Combine
import Foundation
import os

public extension GCDTimer {
    static func publish(every: TimeInterval, receiveQueue: DispatchQueue = .main) -> GCDTimerPublisher {
        GCDTimerPublisher(interval: every, receiveQueue: receiveQueue)
    }
}

public final class GCDTimerPublisher: ConnectablePublisher {
    public typealias Output = Date
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
                    let now = Date()
                    for side in sides.values {
                        side.send(now)
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
            sides[inner.combineIdentifier] = Side(send: inner.send(_:))
            subscriber.receive(subscription: inner)
        }
    }
    
    private func disconnect(_ innerID: CombineIdentifier) {
        sides.withLock { sides in
            sides[innerID] = nil
        }
    }
    
    private struct Side {
        let send: (Date) -> Void
    }
    
    private final class Inner<Downstream: Subscriber>: Subscription where Downstream.Input == Date, Downstream.Failure == Never {
        private weak var parent: GCDTimerPublisher?
        private var downstream: Downstream?
        private var pending = Subscribers.Demand.none
        private let lock = OSAllocatedUnfairLock()
        
        init(parent: GCDTimerPublisher, downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        func send(_ date: Date) {
            lock.withLock {
                guard let downstream, pending != .none else { return }
                pending -= 1
                let newDemand = downstream.receive(date)
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
