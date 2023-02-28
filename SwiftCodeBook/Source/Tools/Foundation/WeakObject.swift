//
//  WeakObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public final class WeakObject<T: AnyObject> {
    public private(set) weak var value: T?
    public init(_ value: T) { self.value = value }
}
