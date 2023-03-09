//
//  LazySafe.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/22.
//

import UIKit

class LazySafe {
    var view: UIView {
        enum Once {
            static var view = {
                UIView()
            }()
        }
        return Once.view
    }
}
