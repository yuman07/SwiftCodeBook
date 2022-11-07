//
//  GCDTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/7.
//

import Foundation

final class GCDTimer {
    private enum State {
        case inited
        case running
        case paused
        case stoped
    }
    
    private let lock = UnfairLock()
    private var state = State.inited
    private var count = 0
    private let timer: DispatchSourceTimer
    private let timeInterval: TimeInterval
    
    init(timeInterval: TimeInterval, repeats: Bool, queue: DispatchQueue = .main, block: @escaping ((_ count: Int) -> Void)) {
        self.timeInterval = timeInterval
        self.timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        self.timer.setEventHandler { [weak self] in
            guard let self else { return }
            block(self.count)
            self.count += 1
            if !repeats { self.stop() }
        }
    }
    
    deinit {
        stop()
    }
    
    func start() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state == .inited || state == .paused else { return }
        if state == .inited {
            timer.schedule(deadline: .now() + timeInterval, repeating: .milliseconds(Int(timeInterval * 1000)))
        }
        timer.resume()
        state = .running
    }
    
    func pause() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state == .running else { return }
        timer.suspend()
        state = .paused
    }
    
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        guard state != .stoped else { return }
        if state == .inited {
            timer.resume()
        }
        timer.cancel()
        state = .stoped
    }
}
