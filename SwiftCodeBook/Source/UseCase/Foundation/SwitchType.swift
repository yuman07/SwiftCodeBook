//
//  SwitchType.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/5/21.
//

import Foundation

func switchType() {
    let item: Any = 0
    switch item {
    case let item as Int:
        print(item)
    case let item as String:
        print(item)
    case let item as Double:
        print(item)
    default:
        break
    }
}
