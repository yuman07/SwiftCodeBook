//
//  NSString+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/2/13.
//

import Foundation

public extension NSString {
    func validatedNSRange(_ range: Range<String.Index>) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
    
    func validatedNSRange(_ range: ClosedRange<String.Index>) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
    
    func validatedNSRange(_ range: PartialRangeFrom<String.Index>) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
    
    func validatedNSRange(_ range: PartialRangeUpTo<String.Index>) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
    
    func validatedNSRange(_ range: PartialRangeThrough<String.Index>) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
    
    func validatedNSRange(_ range: NSRange) -> NSRange? {
        guard case let string = self as String,
            let validatedRange = string.validatedRange(range) else  {
            return nil
        }
        return NSRange(validatedRange, in: string)
    }
}
