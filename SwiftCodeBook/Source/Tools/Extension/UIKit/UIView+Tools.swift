//
//  UIView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit
import WebKit

public extension UIView {
    func removeAllSubviews() {
        while let last = subviews.last {
            last.removeFromSuperview()
        }
    }
    
    func removeAllGestureRecognizers() {
        while let last = gestureRecognizers?.last {
            removeGestureRecognizer(last)
        }
    }
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = next
        while parentResponder != nil {
            if let vc = parentResponder as? UIViewController {
                return vc
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}

private extension UIGestureRecognizer {
    enum AssociatedKeys {
        static var action: Void?
    }
    
    var action: ((UIGestureRecognizer) -> Void)? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.action) as? (UIGestureRecognizer) -> Void }
        set { objc_setAssociatedObject(self, &AssociatedKeys.action, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

public extension UIView {
    func addTapGesture(numberOfTapsRequired: Int = 1, action: @escaping (UIGestureRecognizer) -> Void) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(gestureAction(gesture:)))
        tap.numberOfTapsRequired = numberOfTapsRequired
        tap.action = action
        addGestureRecognizer(tap)
    }
    
    func addLongPressGesture(action: @escaping (UIGestureRecognizer) -> Void) {
        let long = UILongPressGestureRecognizer(target: self, action: #selector(gestureAction(gesture:)))
        long.action = action
        addGestureRecognizer(long)
    }
    
    @objc
    private func gestureAction(gesture: UIGestureRecognizer) {
        gesture.action?(gesture)
    }
}

public extension UIView {
    // https://chromium.googlesource.com/chromium/src.git/+/refs/heads/main/ios/chrome/browser/snapshots/model
    // https://github.com/CoderZhuXH/XHLaunchAd/issues/224
    func toImage() -> UIImage {
        UIGraphicsImageRenderer(size: bounds.size).image {
            if window != nil && viewHierarchyContainsWKWebView() {
                drawHierarchy(in: bounds, afterScreenUpdates: true)
            } else {
                layer.render(in: $0.cgContext)
            }
        }
    }
    
    private func viewHierarchyContainsWKWebView() -> Bool {
        if self is WKWebView && !isHidden && alpha > 0 && bounds.size.width > 0 && bounds.size.height > 0 {
            return true
        }
        return subviews.contains { $0.viewHierarchyContainsWKWebView() }
    }
}
