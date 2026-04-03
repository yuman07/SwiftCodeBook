//
//  UIInterfaceOrientation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/4/3.
//

#if os(macOS) || os(tvOS) || os(watchOS)
import Foundation

public enum UIInterfaceOrientation: Int, Sendable {
    case unknown = 0
    case portrait = 1
    case portraitUpsideDown = 2
    case landscapeLeft = 4
    case landscapeRight = 3
    
    public var isLandscape: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }
    
    public var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
}
#endif
