//
//  NoZoomWKWebView.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/6/21.
//

import UIKit
import WebKit

final class NoZoomWKWebView: WKWebView {
  private var html: String?

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init() {
    // 普通的WKWebView会有双击/双指缩放的特性，通过以下代码禁用
    // https://stackoverflow.com/questions/40452034/disable-zoom-in-wkwebview
    let source = "var meta = document.createElement('meta');meta.name = 'viewport';meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';var head = document.getElementsByTagName('head')[0];head.appendChild(meta);"
    let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    let userContentController = WKUserContentController()
    let config = WKWebViewConfiguration()
    userContentController.addUserScript(script)
    config.userContentController = userContentController
    super.init(frame: .zero, configuration: config)
  }
}
