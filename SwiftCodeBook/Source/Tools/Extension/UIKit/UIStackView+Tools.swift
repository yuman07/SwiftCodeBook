//
//  UIStackView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/1/18.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

public extension UIStackView {
    func removeAllArrangedSubviews() {
        while let last = arrangedSubviews.last {
            removeArrangedSubview(last)
        }
    }
}
#endif
