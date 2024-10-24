//
//  Spacer+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/10/24.
//

import SwiftUI

public extension Spacer {
    static var zero: Self {
        Spacer(minLength: 0)
    }
    
    static func height(_ height: CGFloat) -> some View {
        Spacer.zero.frame(height: height)
    }
    
    static func width(_ width: CGFloat) -> some View {
        Spacer.zero.frame(width: width)
    }
}

