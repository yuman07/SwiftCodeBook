//
//  UILabel.lineRange.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import UIKit

// The following two methods must be satisfied at the same time when calling:
// 1) The label has been laid out, that is, the frame has been determined
// 2) The content of the label is fully displayed, or the lineBreakMode is byWordWrapping
extension UILabel {
    // Ask for the NSRange of each line of text corresponding to the text when displaying
    var lineRanges: [NSRange] {
        var ranges = [NSRange]()
        guard let attributedText else { return ranges }
        
        let mode = lineBreakMode
        lineBreakMode = .byWordWrapping
        defer { lineBreakMode = mode }
        
        let frameSetter = CTFramesetterCreateWithAttributedString(attributedText)
        let path = CGMutablePath()
        path.addRect(bounds)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)
        guard let lines = CTFrameGetLines(frame) as? [CTLine] else { return ranges }
        
        for line in lines {
            let lineRange = CTLineGetStringRange(line)
            ranges.append(NSRange(location: lineRange.location, length: lineRange.length))
        }
        
        return ranges
    }
    
    // Find the corresponding rects in the label when a textRange is displayed (because there will be line breaks)
    func subRectsWith(range: NSRange) -> [CGRect] {
        var rects = [CGRect]()
        guard let attributedText, range.length > 0 else { return rects }
        
        let mode = lineBreakMode
        lineBreakMode = .byWordWrapping
        defer { lineBreakMode = mode }
        
        let textStorage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        for lineRange in lineRanges {
            guard let subRange = range.intersection(lineRange) else { continue }
            var glyphRange = NSRange()
            layoutManager.characterRange(forGlyphRange: subRange, actualGlyphRange: &glyphRange)
            rects.append(layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer))
        }
        
        return rects
    }
}
