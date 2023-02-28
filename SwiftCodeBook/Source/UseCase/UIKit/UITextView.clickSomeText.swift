//
//  UITextView.clickSomeText.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/2/28.
//

import UIKit

private final class ClickTextVC: UIViewController {
    private var rects = [CGRect]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let textView = UITextView(frame: CGRect(x: 100, y: 100, width: 100, height: 100))
        let attString = NSMutableAttributedString(string: "你好啊你好啊你好啊你好啊你好啊你好啊，详情请参阅《个人信息保护法》的相关规定")
        let range = NSRange(location: 24, length: 9)
        attString.addAttributes([.foregroundColor: UIColor.blue], range: range)
        textView.attributedText = attString
        view.addSubview(textView)
        
        textView.addTapGesture { [weak self] gr in
            guard let self, self.rects.contains(where: { $0.contains(gr.location(in: gr.view)) }) else { return }
            print("clicked!!!")
        }
        
        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end)
        else { return }
        
        rects = textView.selectionRects(for: textRange).map { $0.rect }
    }
}
