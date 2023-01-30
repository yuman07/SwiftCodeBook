//
//  UIView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIView {
    func addSubviews(_ views: [UIView]) {
        views.forEach { self.addSubview($0) }
    }
    
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
    struct AssociatedKeys {
        static var action = "action"
    }
    
    var action: ((UIGestureRecognizer) -> Void)? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.action) as? ((UIGestureRecognizer) -> Void)
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.action, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

public extension UIView {
    func addTapGesture(numberOfTapsRequired: Int = 1, action: @escaping (UIGestureRecognizer) -> Void) {
        let tap = UITapGestureRecognizer(target: self, action: #selector(gestureAction(gr:)))
        tap.numberOfTapsRequired = numberOfTapsRequired
        tap.action = action
        addGestureRecognizer(tap)
    }
    
    func addLongPressGesture(action: @escaping (UIGestureRecognizer) -> Void) {
        let long = UILongPressGestureRecognizer(target: self, action: #selector(gestureAction(gr:)))
        long.action = action
        addGestureRecognizer(long)
    }
    
    @objc
    private func gestureAction(gr: UIGestureRecognizer) {
        gr.action?(gr)
    }
}
