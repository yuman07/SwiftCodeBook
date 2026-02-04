//
//  UIViewController+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/4.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

public extension UIViewController {
    func addChildSafely(_ child: UIViewController, layout: (_ child: UIViewController, _ parent: UIViewController) -> Void) {
        guard child.parent != self else { return }
        guard child.parent == nil else { return child.removeFromParentSafely() }
        addChild(child)
        view.addSubview(child.view)
        layout(child, self)
        child.didMove(toParent: self)
    }
    
    func removeFromParentSafely() {
        guard parent != nil else { return }
        willMove(toParent: nil)
        view.removeFromSuperview()
        removeFromParent()
    }
    
    func removeAllChildren() {
        while let last = children.last {
            last.removeFromParentSafely()
        }
    }
}
#endif
