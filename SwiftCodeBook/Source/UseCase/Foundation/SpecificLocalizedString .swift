//
//  SpecificLocalizedString .swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/5/18.
//

import Foundation

// 有时我们需要在多语言的情况下，获取某种特定语言下的字符串(这里以要获取简体中文为例)
private func simplifiedChineseLocalizedString(with key: String) -> String? {
    guard let path = Bundle.main.path(forResource: "zh-Hans", ofType: "lproj"),
          let bundle = Bundle(path: path) else { return nil }
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}
