//
//  UITextView.clickSomeText.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/28.
//

import UIKit

private final class ClickTextVC: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let textView = UITextView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
        textView.isSelectable = false
        let attString = NSMutableAttributedString(string: "你好啊你好啊你好啊你好啊你好啊你好啊，详情请参阅《个人信息保护法》的相关规定")
        guard case let range = (attString.string as NSString).range(of: "《个人信息保护法》"), range.isValid else { return }
        attString.addAttribute(.foregroundColor, value: UIColor.blue, range: range)
        textView.attributedText = attString
        textView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapAction)))
        view.addSubview(textView)
    }
    
    @objc private func tapAction(_ gr: UIGestureRecognizer) {
        guard let textView = gr.view as? UITextView,
              case let range = (textView.text as NSString).range(of: "《个人信息保护法》"), range.isValid,
              case let location = gr.location(in: gr.view),
              let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end),
              case let rects = textView.selectionRects(for: textRange).map(\.rect),
              rects.contains(where: { $0.contains(location) })
        else { return }
        
        print("clicked")
    }
}
