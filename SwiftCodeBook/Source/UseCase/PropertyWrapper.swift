//
//  PropertyWrapper.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/25.
//

import Foundation

@propertyWrapper
struct Limit0To1Case1 {
    private var number = 0.0
    var wrappedValue: Double {
        get { number }
        set { number = max(0, min(1, newValue)) }
    }
}

@propertyWrapper
struct Limit0To1Case2 {
    private var number = 0.0
    var wrappedValue: Double {
        get { number }
        set { number = max(0, min(1, newValue)) }
    }
    
    init(initValue: Double = 0) {
        self.wrappedValue = initValue
    }
}

@propertyWrapper
struct LimitAToB {
    private var number = 0.0
    private var minNum: Double
    private var maxNum: Double
    var wrappedValue: Double {
        get { number }
        set { number = max(minNum, min(maxNum, newValue)) }
    }
    
    init(initValue: Double = 0, minNum: Double = 0, maxNum: Double = 1) {
        self.minNum = minNum
        self.maxNum = maxNum
        self.wrappedValue = initValue
    }
}

@propertyWrapper
struct UserDefaultWrapper<T> {
    private let key: String
    var wrappedValue: T? {
        get { UserDefaults.standard.object(forKey: key) as? T }
        set { UserDefaults.standard.setValue(newValue, forKey: key) }
    }
    
    init(_ key: String) {
        self.key = key
    }
}

class propertyWrapperCase {
    @Limit0To1Case1 var num1: Double
    @Limit0To1Case2(initValue: 0.5) var num2: Double
    @LimitAToB(initValue: 0.5, minNum: -1, maxNum: 1) var num3: Double
    @UserDefaultWrapper("123") var value: String?
    
    func test() {
        // print(num1.wrappedValue)
        print(num1)
        // num1.wrappedValue = 2.0
        num1 = 2.0
    }
}
