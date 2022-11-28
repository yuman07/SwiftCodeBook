//
//  WeakObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

final class WeakObject<T: AnyObject> {
    private(set) weak var value: T?
    init(_ value: T) { self.value = value }
}
