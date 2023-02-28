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
        let attString = NSMutableAttributedString(string: "你好啊你好啊你好啊你好啊你好啊你好啊，详情请参阅《个人信息保护法》的相关规定")
        guard case let range = (attString.string as NSString).range(of: "《个人信息保护法》"), range.isValid else { return }
        attString.addAttributes([.foregroundColor: UIColor.blue], range: range)
        textView.attributedText = attString
        view.addSubview(textView)
        
        var rects = [CGRect]()
        
        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end)
        else { return }
        
        // 注意：这个计算必须满足此时textView已经layout finished
        // 这里为了方便，就使用了手动布局，因此可以直接计算
        // 如果是自动布局，则可以把该方法放到比如viewDidLayoutSubviews()中
        rects = textView.selectionRects(for: textRange).map { $0.rect }
        
        textView.addTapGesture { gr in
            guard rects.contains(where: { $0.contains(gr.location(in: gr.view)) }) else { return }
            print("clicked!!!")
        }
    }
}
