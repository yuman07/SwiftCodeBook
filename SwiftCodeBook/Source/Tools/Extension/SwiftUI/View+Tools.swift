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
}
