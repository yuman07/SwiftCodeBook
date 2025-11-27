//
//  AnimationTimer.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/11/27.
//

import Foundation
import UIKit

@MainActor
final public class AnimationTimer {
    private let duration: TimeInterval
    
    private var timer: CADisplayLink?
    private var finishedDuration = TimeInterval.zero
    private var animations = [(CGFloat) -> Void]()
    private var completions = [(UIViewAnimatingPosition) -> Void]()
    
    public init(duration: TimeInterval) {
        self.duration = duration
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
    
    public func addCompletion(_ completion: @escaping (UIViewAnimatingPosition) -> Void) {
        completions.append(completion)
    }
    
    @objc private func updateAnimation(_ timer: CADisplayLink) {
        finishedDuration += TimeInterval(timer.targetTimestamp) - TimeInterval(timer.timestamp)
        let progress = CGFloat(finishedDuration / duration)
        
        if progress >= 1 {
            finishAnimation(at: .end)
        } else {
            for animation in animations {
                animation(progress)
            }
        }
    }
}
