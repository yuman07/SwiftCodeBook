//
//  Result+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: true
        case .failure: false
        }
    }
    
    var value: Success? {
        switch self {
        case let .success(val): val
        case .failure: nil
        }
    }
    
    var error: Failure? {
        switch self {
        case .success: nil
        case let .failure(err): err
        }
    }
}
