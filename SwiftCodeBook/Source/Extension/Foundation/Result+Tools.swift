//
//  Result+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var value: Success? {
        switch self {
        case let .success(val): return val
        case .failure: return nil
        }
    }
}
