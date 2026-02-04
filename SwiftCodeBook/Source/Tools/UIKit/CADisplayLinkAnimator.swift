//
//  AnimationTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/11/27.
//

#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
import Foundation
import QuartzCore
#if canImport(UIKit)
import UIKit
#else
public enum UIViewAnimatingPosition: Int, Sendable {
    case end = 0
    case start = 1
    case current = 2
}
#endif

@MainActor
final public class CADisplayLinkAnimator: Sendable {
    private let duration: Duration
    private let cubicBezier: CubicBezier
    private let preferredFrameRateRange: CAFrameRateRange?
    
    private var timer: CADisplayLink?
    private var finishedDuration = TimeInterval.zero
    private var animations = [(CGFloat) -> Void]()
    private var completions = [(UIViewAnimatingPosition) -> Void]()
    
    public init(duration: Duration, timingFunctionName: CAMediaTimingFunctionName = .default, preferredFrameRateRange: CAFrameRateRange? = nil) {
        self.duration = duration
        self.cubicBezier = CubicBezier(timingFunctionName: timingFunctionName)
        self.preferredFrameRateRange = preferredFrameRateRange
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    public func startAnimation() {
        finishedDuration = 0
        timer?.invalidate()
        timer = CADisplayLink(target: self, selector: #selector(updateAnimation))
        preferredFrameRateRange.flatMap { timer?.preferredFrameRateRange = $0 }
        timer?.add(to: .main, forMode: .common)
    }
    
    public func finishAnimation(at finalPosition: UIViewAnimatingPosition) {
        timer?.invalidate()
        timer = nil
        switch finalPosition {
        case .end:
            for animation in animations {
                animation(1)
            }
            for completion in completions {
                completion(.end)
            }
        case .start:
            for animation in animations {
                animation(0)
            }
            for completion in completions {
                completion(.start)
            }
        case .current:
            for completion in completions {
                completion(.current)
            }
        @unknown default:
            break
        }
    }
    
    public func addAnimation(_ animation: @escaping (_ progress: CGFloat) -> Void) {
        animations.append(animation)
    }
    
    public func addCompletion(_ completion: @escaping (_ finalPosition: UIViewAnimatingPosition) -> Void) {
        completions.append(completion)
    }
    
    @objc private func updateAnimation(_ link: CADisplayLink) {
        finishedDuration += TimeInterval(link.targetTimestamp - link.timestamp)
        let progress = cubicBezier.value(at: CGFloat(finishedDuration / duration.seconds))
        
        if progress >= 1 {
            finishAnimation(at: .end)
        } else {
            for animation in animations {
                animation(progress)
            }
        }
    }
}

@MainActor
private struct CubicBezier: Sendable {
    private let ax: CGFloat
    private let bx: CGFloat
    private let cx: CGFloat
    private let ay: CGFloat
    private let by: CGFloat
    private let cy: CGFloat
    private let timingFunctionName: CAMediaTimingFunctionName
    
    init(timingFunctionName: CAMediaTimingFunctionName) {
        let timingFunction = CAMediaTimingFunction(name: timingFunctionName)
        var p1: [Float] = [0, 0]
        var p2: [Float] = [0, 0]
        timingFunction.getControlPoint(at: 1, values: &p1)
        timingFunction.getControlPoint(at: 2, values: &p2)
        
        let x1 = CGFloat(p1[0])
        let y1 = CGFloat(p1[1])
        let x2 = CGFloat(p2[0])
        let y2 = CGFloat(p2[1])
        
        self.cx = 3 * x1
        self.bx = 3 * x2 - 6 * x1
        self.ax = 3 * x1 - 3 * x2 + 1
        self.cy = 3 * y1
        self.by = 3 * y2 - 6 * y1
        self.ay = 3 * y1 - 3 * y2 + 1
        self.timingFunctionName = timingFunctionName
    }
    
    func value(at t: CGFloat) -> CGFloat {
        let targetX = max(0, min(1, t))
        if targetX <= 0 { return 0 }
        if targetX >= 1 { return 1 }
        if timingFunctionName == .linear { return targetX }
        let s = solveForS(targetX: targetX)
        return max(0, min(1, sampleY(s)))
    }
    
    private func sampleX(_ s: CGFloat) -> CGFloat {
        ((ax * s + bx) * s + cx) * s
    }
    
    private func sampleDX(_ s: CGFloat) -> CGFloat {
        (3 * ax * s * s) + (2 * bx * s) + cx
    }
    
    private func sampleY(_ s: CGFloat) -> CGFloat {
        ((ay * s + by) * s + cy) * s
    }
    
    private func solveForS(targetX t: CGFloat) -> CGFloat {
        var s = t
        for _ in 0 ..< 8 {
            let x = sampleX(s)
            let err = x - t
            if abs(err) < 1e-8 { break }
            
            let dx = sampleDX(s)
            if abs(dx) < 1e-12 { break }
            
            s -= err / dx
            s = max(0, min(1, s))
        }
        return s
    }
}
#endif
