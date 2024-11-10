//
//  GCDTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/7.
//

import Foundation

public final class GCDTimer: @unchecked Sendable {
    private enum State {
        case inited
        case running
        case paused
        case stoped
    }
    
    private var state = State.inited
    private var count = 0
    private let timer: DispatchSourceTimer
    private let timeInterval: TimeInterval
    private let queue = DispatchQueue(label: "SwiftCodeBook.GCDTimerQueue")
    
    public init(timeInterval: TimeInterval, repeats: Bool, queue: DispatchQueue = .main, block: @escaping (_ count: Int) -> Void) {
        self.timeInterval = timeInterval
        self.timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        self.timer.setEventHandler { [weak self] in
            guard let self else { return }
            block(count)
            if !repeats { stop() }
            count += 1
        }
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        queue.sync {
            switch state {
            case .running, .stoped:
                return
            case .paused:
                break
            case .inited:
                timer.schedule(deadline: .now() + timeInterval, repeating: .milliseconds(Int(timeInterval * 1000)))
            }
            timer.resume()
            state = .running
        }
    }
    
    public func pause() {
        queue.sync {
            guard state == .running else { return }
            timer.suspend()
            state = .paused
        }
    }
    
    public func stop() {
        queue.sync {
            guard state != .stoped else { return }
            timer.setEventHandler(handler: nil)
            if state == .inited { timer.resume() }
            timer.cancel()
            state = .stoped
        }
    }
}
