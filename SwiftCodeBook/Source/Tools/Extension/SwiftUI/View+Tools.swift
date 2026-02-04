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
        if let view = transform(self), !(view is EmptyView) {
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
    
    func onFrameChange(in coordinateSpace: CoordinateSpaceProtocol, _ action: @escaping @MainActor (_ newFrame: CGRect) -> Void) -> some View {
        onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: coordinateSpace)
        } action: { frame in
            action(frame)
        }
    }

    func onSafeAreaInsetsChange(_ action: @escaping @MainActor (_ newSafeAreaInsets: EdgeInsets) -> Void) -> some View {
        onGeometryChange(for: EdgeInsets.self) { proxy in
            proxy.safeAreaInsets
        } action: { edgeInsets in
            action(edgeInsets)
        }
    }
}

public extension View {
    func onWindowSizeChanged(_ handler: @escaping @MainActor (CGSize?) -> Void) -> some View {
#if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
        background(WindowExtractor(onChange: handler).allowsHitTesting(false).accessibilityHidden(true))
#elseif os(watchOS)
        DispatchQueue.main.async {
            handler(WKInterfaceDevice.current().screenBounds.size)
        }
        return self
#else
        self
#endif
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
private struct WindowExtractor: UIViewRepresentable {
    let onChange: @MainActor (CGSize?) -> Void

    func makeUIView(context: Context) -> WindowTrackingView {
        WindowTrackingView(onChange: onChange)
    }

    func updateUIView(_ uiView: WindowTrackingView, context: Context) {
        uiView.onChange = onChange
    }

    final class WindowTrackingView: UIView {
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
                .flatMap({ window -> AnyPublisher<CGSize?, Never> in
                    guard let window else { return Just(nil).eraseToAnyPublisher() }
                    return window.publisher(for: \.frame).map(\.size).eraseToAnyPublisher()
                })
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] size in
                    self?.onChange(size)
                }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            parentWindow = window
        }
    }
}
#elseif os(macOS)
private struct WindowExtractor: NSViewRepresentable {
    let onChange: @MainActor (CGSize?) -> Void

    func makeNSView(context: Context) -> WindowTrackingView {
        WindowTrackingView(onChange: onChange)
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        nsView.onChange = onChange
    }

    final class WindowTrackingView: NSView {
        var onChange: (@MainActor (CGSize?) -> Void)
        @Published private var parentWindow: NSWindow?
        private var cancelToken: AnyCancellable?

        init(onChange: @escaping @MainActor (CGSize?) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isHidden = true
            layer?.backgroundColor = .clear
            
            cancelToken = $parentWindow
                .flatMap({ window -> AnyPublisher<CGSize?, Never> in
                    guard let window else { return Just(nil).eraseToAnyPublisher() }
                    return window.publisher(for: \.frame).map(\.size).eraseToAnyPublisher()
                })
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] size in
                    self?.onChange(size)
                }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
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
