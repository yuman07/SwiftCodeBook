//
//  CodeBookHelper.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/24.
//

import AVKit
import Foundation

enum CodeBookHelper {
    static func timeCost(action: () -> Void, repeats: Int = 1) {
        let begin = CACurrentMediaTime()
        for _ in 0 ..< repeats {
            action()
        }
        let total = TimeInterval((CACurrentMediaTime() - begin) * 1000)
        print("总耗时：\(total) ms")
        print("平均耗时：\(total / TimeInterval(repeats)) ms")
    }
}
