//
//  LazySafe.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/22.
//

import Foundation

private class LazySafe {
    private var _age: Int?
    var age: Int? {
        DispatchQueue.runOnce {
            _age = Int.random(in: 1...100)
        }
        return _age
    }
}
