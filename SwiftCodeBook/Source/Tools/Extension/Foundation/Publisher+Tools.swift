//
//  Publisher+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import Combine

public extension Publisher {
    func sinkToResult(_ result: @escaping (Result<Output, Failure>?) -> Void) -> AnyCancellable {
        sink(receiveCompletion: {
            switch $0 {
            case .finished: result(nil)
            case let .failure(error): result(.failure(error))
            }
        }, receiveValue: {
            result(.success($0))
        })
    }
    
    func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
        scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
}
