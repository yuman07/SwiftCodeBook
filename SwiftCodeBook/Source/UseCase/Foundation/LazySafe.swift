//
//  LazySafe.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/22.
//

import UIKit

// 这里仅保证view的懒加载过程是线程安全的
// 注意set/get仍不是线程安全的
class LazySafe {
    lazy var view: UIView = {
        enum Once {
            static var view = {
                UIView()
            }()
        }
        return Once.view
    }()
}
