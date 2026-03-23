//
//  CADisplayLinkTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/3/20.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import Foundation
import QuartzCore

@MainActor
public final class CADisplayLinkTimer {
    @MainActor
    private final class CADisplayLinkProxy {
        private weak let target: CADisplayLinkTimer?
        
        init(_ target: CADisplayLinkTimer?) {
            self.target = target
        }
        
        @objc func updateDisplayLink(_ displayLink: CADisplayLink) {
            target?.updateDisplayLink(displayLink)
        }
    }
    
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval?
    private let preferredFrameRateRange: CAFrameRateRange?
    private let block: @MainActor (_ elapsedTime: TimeInterval) -> Void
    
    public init(preferredFrameRateRange: CAFrameRateRange? = nil, block: @escaping @MainActor (_ elapsedTime: TimeInterval) -> Void) {
        self.preferredFrameRateRange = preferredFrameRateRange
        self.block = block
    }
    
    @MainActor
    deinit {
        stop()
    }
    
    public func start() {
        stop()
        displayLink = CADisplayLink(target: CADisplayLinkProxy(self), selector: #selector(CADisplayLinkProxy.updateDisplayLink(_:)))
        preferredFrameRateRange.flatMap { displayLink?.preferredFrameRateRange = $0 }
        displayLink?.add(to: .main, forMode: .common)
    }
    
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        startTimestamp = nil
    }
    
    private func updateDisplayLink(_ displayLink: CADisplayLink) {
        if let start = startTimestamp {
            block(TimeInterval(displayLink.timestamp - start))
        } else {
            startTimestamp = displayLink.timestamp
            block(0)
        }
    }
}
#endif
