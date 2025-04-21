//
//  View+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/27.
//

import SwiftUI

public extension View {
    @ViewBuilder func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self), !(view is EmptyView) {
            view
        } else {
            self
        }
    }
    
    func onSizeChange(_ action: @escaping (_ newSize: CGSize) -> Void) -> some View {
        self.onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            action(size)
        }
    }
    
    func onFrameChange(in coordinateSpace: CoordinateSpaceProtocol, _ action: @escaping (_ newFrame: CGRect) -> Void) -> some View {
        self.onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: coordinateSpace)
        } action: { frame in
            action(frame)
        }
    }
}
