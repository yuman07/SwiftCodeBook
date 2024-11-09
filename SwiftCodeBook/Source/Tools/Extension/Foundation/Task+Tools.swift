//
//  Task+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/30.
//

import Combine
import Foundation

public extension Task {
    var toAnyCancellable: AnyCancellable {
        AnyCancellable({ cancel() })
    }
    
    func store(in cancelBag: CancelBag) {
        toAnyCancellable.store(in: cancelBag)
    }
}
