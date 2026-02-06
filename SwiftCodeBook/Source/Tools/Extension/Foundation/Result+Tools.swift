//
//  Result+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Foundation

public extension Result {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }
    
    var value: Success? {
        guard case let .success(val) = self else { return nil }
        return val
    }
    
    var error: Failure? {
        guard case let .failure(err) = self else { return nil }
        return err
    }
}
