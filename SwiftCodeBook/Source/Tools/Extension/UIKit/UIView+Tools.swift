//
//  UIView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

public extension UIView {
    func removeAllSubviews() {
        while !subviews.isEmpty {
            subviews.last?.removeFromSuperview()
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
