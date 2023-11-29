//
//  CompareEnum.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/11/29.
//

import Foundation

private enum Content {
    case text(String)
    case image(url: URL)
}

func compareEnum() -> Bool {
    let contentA = Content.text("123")
    let contentB = Content.image(url: .blank)
    
    switch (contentA, contentB) {
    case let (.text(ls), .text(rs)):
        return ls == rs
    case let (.image(lu), .image(ru)):
        return lu == ru
    default:
        return false
    }
}

func checkEnumIsSomeCase() {
    let content = Content.text("123")
    if case .text = content {
        print("is text case")
    } else {
        print("is not text")
    }
}
