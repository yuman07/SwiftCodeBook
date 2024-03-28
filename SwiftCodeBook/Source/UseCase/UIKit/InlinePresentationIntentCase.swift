//
//  InlinePresentationIntentCase.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/28.
//

import UIKit

func testInlinePresentationIntentCase(contentView: UIView) {
    // 一般情况下，字体的加粗或者斜体都是和字体本身绑定的，即必须添加一个指定的boldFont来实现
    // 但有时的需求是比如我们不关心最终用什么字体呈现，但某部分文字必须加粗。这时可以用InlinePresentationIntent来实现
    let styles: [InlinePresentationIntent] = [.emphasized, .stronglyEmphasized, .code, .strikethrough, .softBreak, .lineBreak, .inlineHTML, .blockHTML]
    
    styles.enumerated().forEach { idx, value in
        let attString = NSMutableAttributedString(string: "你好TestStyle世界")
        attString.addAttribute(.inlinePresentationIntent, value: value.rawValue, range: NSRange(location: 2, length: 9))
        attString.addAttribute(.font, value: UIFont.systemFont(ofSize: 14), range: NSRange(location: 0 , length: attString.length))
        let label = UILabel(frame: CGRect(x: 50, y: CGFloat(idx + 1) * 80, width: 0, height: 0))
        label.numberOfLines = 0
        label.attributedText = attString
        label.sizeToFit()
        contentView.addSubview(label)
    }
}
