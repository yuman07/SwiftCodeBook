//
//  LyricHighlightingLabel.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import UIKit

// 歌词式高亮Label
// highlightColor为高亮色，textColor为底色，progress为进度
// 1) 该Label只能支持一行文本的样式
// 2) highlightColor和textColor不能设置相同的颜色，不然会有UIBug
final class LyricHighlightingLabel: UILabel {
    var highlightColor = UIColor.clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var progress = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        highlightColor.set()
        let fillRect = CGRect(origin: .zero, size: CGSize(width: rect.width * progress, height: rect.height))
        UIRectFillUsingBlendMode(fillRect, .sourceIn)
    }
}
