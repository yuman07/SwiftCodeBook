//
//  GCDTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/7.
//

import Foundation
import os

public final class GCDTimer: @unchecked Sendable {
    private enum State {
        case idle
        case running
        case paused
        case stoped
    }
    
    private let count = OSAllocatedUnfairLock(initialState: 0)
    private let state = OSAllocatedUnfairLock(initialState: State.idle)
    private let timer: DispatchSourceTimer
    private let timeInterval: TimeInterval
    
    public init(timeInterval: TimeInterval, repeats: Bool, queue: DispatchQueue = .main, block: @escaping (_ count: Int) -> Void) {
        self.timeInterval = timeInterval
        self.timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        self.timer.setEventHandler { [weak self] in
            guard let self else { return }
            let curCount = count.withLock { count in
                let curCount = count
                count += 1
                return curCount
            }
            block(curCount)
            if !repeats { stop() }
        }
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        state.withLock { state in
            switch state {
            case .running, .stoped:
                return
            case .paused:
                break
            case .idle:
                timer.schedule(deadline: .now() + timeInterval, repeating: .milliseconds(Int(timeInterval * 1000)))
            }
            timer.resume()
            state = .running
        }
    }
    
    public func pause() {
        state.withLock { state in
            guard state == .running else { return }
            timer.suspend()
            state = .paused
        }
    }
    
    public func stop() {
        state.withLock { state in
            guard state != .stoped else { return }
            timer.setEventHandler(handler: nil)
            if state == .idle { timer.resume() }
            timer.cancel()
            state = .stoped
        }
    }
}
