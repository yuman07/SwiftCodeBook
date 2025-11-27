//
//  AnimationTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/11/27.
//

import Foundation
import QuartzCore
import UIKit

@MainActor
final public class AnimationTimer {
    @frozen public enum TimingFunction {
        case linear
        case easeIn
        case easeOut
        case easeInEaseOut
    }
    
    private let duration: TimeInterval
    private let timingFunction: TimingFunction
    private let cubicBezier: CubicBezier
    
    private var timer: CADisplayLink?
    private var finishedDuration = TimeInterval.zero
    private var animations = [(CGFloat) -> Void]()
    private var completions = [(UIViewAnimatingPosition) -> Void]()
    
    public init(duration: TimeInterval, timingFunction: TimingFunction) {
        self.duration = duration
        self.timingFunction = timingFunction
        self.cubicBezier = {
            let function: CAMediaTimingFunction
            switch timingFunction {
            case .linear: function = CAMediaTimingFunction(name: .linear)
            case .easeIn: function = CAMediaTimingFunction(name: .easeIn)
            case .easeOut:  function = CAMediaTimingFunction(name: .easeOut)
            case .easeInEaseOut: function = CAMediaTimingFunction(name: .easeInEaseOut)
            }
            var p1: [Float] = [0, 0]
            var p2: [Float] = [0, 0]
            function.getControlPoint(at: 1, values: &p1)
            function.getControlPoint(at: 2, values: &p2)
            return CubicBezier(x1: CGFloat(p1[0]), y1: CGFloat(p1[1]), x2: CGFloat(p2[0]), y2: CGFloat(p2[1]))
        }()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    public func startAnimation() {
        finishedDuration = 0
        timer?.invalidate()
        timer = CADisplayLink(target: self, selector: #selector(updateAnimation))
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
        finishedDuration += TimeInterval(link.targetTimestamp) - TimeInterval(link.timestamp)
        var progress = max(0, min(1, CGFloat(finishedDuration / duration)))
        if timingFunction != .linear {
            progress = cubicBezier.value(at: progress)
        }
        
        if progress >= 1 {
            finishAnimation(at: .end)
        } else {
            for animation in animations {
                animation(progress)
            }
        }
    }
}

private struct CubicBezier {
    private let ax: CGFloat
    private let bx: CGFloat
    private let cx: CGFloat
    private let ay: CGFloat
    private let by: CGFloat
    private let cy: CGFloat
    
    init(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) {
        self.cx = 3 * x1
        self.bx = 3 * x2 - 6 * x1
        self.ax = 3 * x1 - 3 * x2 + 1
        self.cy = 3 * y1
        self.by = 3 * y2 - 6 * y1
        self.ay = 3 * y1 - 3 * y2 + 1
    }
    
    func value(at t: CGFloat) -> CGFloat {
        let targetX = max(0, min(1, t))
        if targetX <= 0 { return 0 }
        if targetX >= 1 { return 1 }
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
        for _ in 0 ..< 7 {
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
