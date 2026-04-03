//
//  View+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/3/27.
//

#if canImport(AppKit)
import AppKit
#endif
import Combine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

public extension View {
    @ViewBuilder func modify(@ViewBuilder _ transform: (Self) -> (some View)?) -> some View {
        if let view = transform(self) {
            view
        } else {
            self
        }
    }
    
    func onSizeChange(_ action: @escaping @MainActor (_ newSize: CGSize) -> Void) -> some View {
        onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            action(size)
        }
    }

    func onSafeAreaInsetsChange(_ action: @escaping @MainActor (_ newSafeAreaInsets: EdgeInsets) -> Void) -> some View {
        onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { edgeInsets in
            action(edgeInsets)
        }
    }
    
    func onWindowSizeChange(_ action: @escaping @MainActor (CGSize?) -> Void) -> some View {
#if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)
        background(WindowSizeObserver(onChange: action).allowsHitTesting(false).accessibilityHidden(true))
#elseif os(watchOS)
        onAppear {
            action(WKInterfaceDevice.current().screenBounds.size)
        }
#else
        self
#endif
    }
    
    func onInterfaceOrientationChange(_ action: @escaping @MainActor (UIInterfaceOrientation) -> Void) -> some View {
#if os(iOS) || os(visionOS)
        background(WindowInterfaceOrientationObserver(onChange: action).allowsHitTesting(false).accessibilityHidden(true))
#else
        self
#endif
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
private struct WindowSizeObserver: UIViewRepresentable {
    let onChange: @MainActor (CGSize?) -> Void

    func makeUIView(context: Context) -> WindowSizeObserverView {
        WindowSizeObserverView(onChange: onChange)
    }

    func updateUIView(_ uiView: WindowSizeObserverView, context: Context) {
        uiView.onChange = onChange
    }

    final class WindowSizeObserverView: UIView {
        var onChange: @MainActor (CGSize?) -> Void
        @Published private var parentWindow: UIWindow?
        private var cancelToken: AnyCancellable?

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isHidden = true
            backgroundColor = .clear
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
            
            cancelToken = $parentWindow
                .map({ window -> AnyPublisher<CGSize?, Never> in
                    guard let window else { return Just(nil).eraseToAnyPublisher() }
                    return window.publisher(for: \.frame).map(\.size).prepend(window.frame.size).eraseToAnyPublisher()
                })
                .switchToLatest()
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] size in
                    self?.onChange(size)
                }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            preconditionFailure("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            parentWindow = window
        }
    }
}
#elseif os(macOS)
private struct WindowSizeObserver: NSViewRepresentable {
    let onChange: @MainActor (CGSize?) -> Void

    func makeNSView(context: Context) -> WindowSizeObserverView {
        WindowSizeObserverView(onChange: onChange)
    }

    func updateNSView(_ nsView: WindowSizeObserverView, context: Context) {
        nsView.onChange = onChange
    }

    final class WindowSizeObserverView: NSView {
        var onChange: @MainActor (CGSize?) -> Void
        @Published private var parentWindow: NSWindow?
        private var cancelToken: AnyCancellable?

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isHidden = true
            
            cancelToken = $parentWindow
                .map({ window -> AnyPublisher<CGSize?, Never> in
                    guard let window else { return Just(nil).eraseToAnyPublisher() }
                    return window.publisher(for: \.frame).map(\.size).prepend(window.frame.size).eraseToAnyPublisher()
                })
                .switchToLatest()
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] size in
                    self?.onChange(size)
                }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            preconditionFailure("init(coder:) has not been implemented")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            parentWindow = window
        }
        
        override func isAccessibilityHidden() -> Bool {
            true
        }
    }
}
#endif

#if os(iOS) || os(visionOS)
private struct WindowInterfaceOrientationObserver: UIViewRepresentable {
    let onChange: @MainActor (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> WindowInterfaceOrientationObserverView {
        WindowInterfaceOrientationObserverView(onChange: onChange)
    }

    func updateUIView(_ uiView: WindowInterfaceOrientationObserverView, context: Context) {
        uiView.onChange = onChange
    }

    final class WindowInterfaceOrientationObserverView: UIView {
        var onChange: @MainActor (UIInterfaceOrientation) -> Void
        @Published private var parentWindow: UIWindow?
        private var cancelToken: AnyCancellable?

        init(onChange: @escaping @MainActor (UIInterfaceOrientation) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isHidden = true
            backgroundColor = .clear
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
            
            cancelToken = $parentWindow
                .map({ window -> AnyPublisher<UIInterfaceOrientation, Never> in
                    guard let windowScene = window?.windowScene else { return Just(.unknown).eraseToAnyPublisher() }
                    return windowScene
                        .publisher(for: \.effectiveGeometry)
                        .map(\.interfaceOrientation)
                        .prepend(windowScene.effectiveGeometry.interfaceOrientation)
                        .eraseToAnyPublisher()
                })
                .switchToLatest()
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] interfaceOrientation in
                    self?.onChange(interfaceOrientation)
                }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            preconditionFailure("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            parentWindow = window
        }
    }
}
#endif
