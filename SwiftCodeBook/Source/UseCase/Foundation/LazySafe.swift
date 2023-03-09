//
//  LazySafe.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/22.
//

import Foundation

class LazySafe {
    var age: Int {
        enum Once {
            static var age = {
                Int.random(in: 1...1000)
            }()
        }
        return Once.age
    }
}
