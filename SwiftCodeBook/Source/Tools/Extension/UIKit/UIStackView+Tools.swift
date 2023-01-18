//
//  UIStackView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/1/18.
//

import UIKit

public extension UIStackView {
    func removeAllArrangedSubviews() {
        while let last = arrangedSubviews.last {
            removeArrangedSubview(last)
        }
    }
}
