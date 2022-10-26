//
//  UIApplication+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

extension UIApplication {
    var keyWindow: UIWindow? {
        let windows = connectedScenes.compactMap{ $0 as? UIWindowScene }.flatMap{ $0.windows }
        return windows.count == 1 ? windows.first : windows.first(where: { $0.isKeyWindow })
    }
}
