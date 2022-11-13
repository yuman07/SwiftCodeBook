//
//  UIScrollView_Scrolling.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/13.
//

import Combine
import UIKit

// The isScrolling flag here works perfectly for the following two scenarios
// 1. When the user manually slides the scrollView
// 2. When sliding is implemented by code. For example, "scrollView.setContentOffset(CGPoint(x: 10, y: 20), animated: true)", note that animated must be true here
//
// There is also a case, when using "scrollView.setContentOffset(CGPoint(x: 10, y: 20), animated: false)" to achieve sliding, isScrolling will become true at this time, but when the scrolling ends, it will not become false.

private final class TestViewController: UIViewController {
    @Published var isScrolling = false
    private var cancelBag = Set<AnyCancellable>()
    
    lazy var scrollView = {
        let view = UIScrollView()
        view.delegate = self
        return view
    }()
    
    func setupCombine() {
        $isScrolling.sink {
            print($0 ? "isScrolling" : "notScrolling")
        }.store(in: &cancelBag)
    }
}

extension TestViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        isScrolling = true
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isScrolling { isScrolling = false }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let scrollToScrollStop = !scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating
        if isScrolling && scrollToScrollStop { isScrolling = false }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let dragToDragStop = scrollView.isTracking && !scrollView.isDragging && !scrollView.isDecelerating
        if !decelerate && dragToDragStop && isScrolling { isScrolling = false }
    }
}
