//
//  LyricHighlightingLabel.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

// 歌词式高亮Label
// highlightColor为高亮色，textColor为底色，progress为进度
// 1) 该Label只能支持一行文本的样式
// 2) highlightColor和textColor不能设置相同的颜色，不然会有UIBug
public final class LyricHighlightingLabel: UILabel {
    public var highlightColor = UIColor.clear {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public var progress = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        highlightColor.set()
        let fillRect = CGRect(origin: .zero, size: CGSize(width: rect.width * progress, height: rect.height))
        UIRectFillUsingBlendMode(fillRect, .sourceIn)
    }
}
#endif
