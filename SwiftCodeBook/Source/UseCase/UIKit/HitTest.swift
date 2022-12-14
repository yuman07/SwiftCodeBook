//
//  HitTest.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/25.
//

import UIKit

class HitTest1View: UIView {
    // Fix the problem that when the subview of a view exceeds itself, clicking the subview beyond the part does not respond
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subView in subviews.reversed() {
            if let view = subView.hitTest(subView.convert(point, from: self), with: event) {
                return view
            }
        }
        return super.hitTest(point, with: event)
    }
}

class HitTest2View: UIView {
    // Hand over all click events of a view to a specific view for processing
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The assumption here is to handle it by yourself, or you can change it to other views as needed
        if super.hitTest(point, with: event) != nil {
            return self
        }
        
        // If it is determined that no child view exceeds the display of the parent view, the following code is not required
        for subView in subviews.reversed() {
            if subView.hitTest(subView.convert(point, from: self), with: event) != nil {
                return self
            }
        }
        
        return nil
    }
}
