//
//  Publisher+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Combine

public extension Publisher {
    func sinkToResult(_ result: @escaping (Result<Output, Failure>) -> Void) -> AnyCancellable {
        sink(receiveCompletion: {
            switch $0 {
            case let .failure(error): result(.failure(error))
            default: break
            }
        }, receiveValue: {
            result(.success($0))
        })
    }
}
