//
//  GCDTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/7.
//

import Foundation

public final class GCDTimer {
    private enum State {
        case inited
        case running
        case paused
        case stoped
    }
    
    private let lock = NSLock()
    private var state = State.inited
    private var count = 0
    private let timer: DispatchSourceTimer
    private let timeInterval: TimeInterval
    
    public init(timeInterval: TimeInterval, repeats: Bool, queue: DispatchQueue = .main, block: @escaping (_ count: Int) -> Void) {
        self.timeInterval = timeInterval
        self.timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        self.timer.setEventHandler { [weak self] in
            guard let self else { return }
            block(count)
            count += 1
            if !repeats { stop() }
        }
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state == .inited || state == .paused else { return }
        if state == .inited { timer.schedule(deadline: .now() + timeInterval, repeating: .milliseconds(Int(timeInterval * 1000))) }
        timer.resume()
        state = .running
    }
    
    public func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state == .running else { return }
        timer.suspend()
        state = .paused
    }
    
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state != .stoped else { return }
        if state == .inited { timer.resume() }
        timer.cancel()
        state = .stoped
    }
}
