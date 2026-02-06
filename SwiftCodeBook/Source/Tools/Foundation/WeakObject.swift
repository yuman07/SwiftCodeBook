//
//  WeakObject.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public final class WeakObject<T: AnyObject> {
    public weak let value: T?
    public init(_ value: T) { self.value = value }
}
