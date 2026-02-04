//
//  UIView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

#if canImport(UIKit)
import Combine
import UIKit

public extension UIView {
    func removeAllSubviews() {
        while let last = subviews.last {
            last.removeFromSuperview()
        }
    }
    
    func removeAllGestureRecognizers() {
        while let last = gestureRecognizers?.last {
            removeGestureRecognizer(last)
        }
    }
    
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = next
        while parentResponder != nil {
            if let vc = parentResponder as? UIViewController {
                return vc
            }
            parentResponder = parentResponder?.next
        }
        return nil
    }
}

public extension UIView {
    var parentWindowPublisher: AnyPublisher<UIWindow?, Never> {
        WindowChangePublisher(host: self)
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var parentWindowSizePublisher: AnyPublisher<CGSize?, Never> {
        parentWindowPublisher
            .flatMap({ window -> AnyPublisher<CGSize?, Never> in
                guard let window else { return Just(nil).eraseToAnyPublisher() }
                return window.publisher(for: \.bounds).map(\.size).eraseToAnyPublisher()
            })
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var interfaceOrientation: UIInterfaceOrientation {
        window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }

    var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never> {
        parentWindowPublisher
            .flatMap({ window -> AnyPublisher<UIInterfaceOrientation, Never> in
                guard let windowScene = window?.windowScene else { return Just(.unknown).eraseToAnyPublisher() }
                return windowScene.publisher(for: \.effectiveGeometry).map(\.interfaceOrientation).eraseToAnyPublisher()
            })
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

private final class WindowObserverView: UIView {
    @Published var parentWindow: UIWindow?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        parentWindow = window
    }
}

private struct WindowChangePublisher: Publisher {
    typealias Output = UIWindow?
    typealias Failure = Never

    weak var host: UIView?

    func receive<S>(subscriber: S) where S: Subscriber, S.Input == UIWindow?, S.Failure == Never {
        subscriber.receive(subscription: WindowSubscription(
            host: host,
            subscriber: subscriber
        ))
    }
}

private final class WindowSubscription<S: Subscriber>: Subscription where S.Input == UIWindow?, S.Failure == Never {
    private weak var host: UIView?
    private var subscriber: S?
    private var cancelToken: AnyCancellable?

    init(host: UIView?, subscriber: S) {
        self.host = host
        self.subscriber = subscriber
        attach()
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        cancelToken?.cancel()
        cancelToken = nil
        subscriber = nil
    }

    private func attach() {
        guard let host else { return }
        let observer = getOrCreateObserver(on: host)
        
        _ = subscriber?.receive(host.window)
        
        cancelToken = observer.$parentWindow
            .sink { [weak self] window in
                guard let self else { return }
                _ = subscriber?.receive(window)
            }
    }
    
    private func getOrCreateObserver(on host: UIView) -> WindowObserverView {
        if let windowObserverView = host.subviews.compactMap({ $0 as? WindowObserverView }).first {
            return windowObserverView
        }

        let observer = WindowObserverView(frame: .zero)
        host.addSubview(observer)

        NSLayoutConstraint.activate([
            observer.topAnchor.constraint(equalTo: host.topAnchor),
            observer.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            observer.widthAnchor.constraint(equalToConstant: 0),
            observer.heightAnchor.constraint(equalToConstant: 0),
        ])
        
        return observer
    }
}

#endif

#if os(iOS) || os(visionOS)
#else
public enum UIInterfaceOrientation: Int, Sendable {
    case unknown = 0
    case portrait = 1
    case portraitUpsideDown = 2
    case landscapeLeft = 4
    case landscapeRight = 3
    
    public var isPortrait: Bool {
        self == .portrait || self == .portraitUpsideDown
    }
    
    public var isLandscape: Bool {
        self == .landscapeLeft || self == .landscapeRight
    }
}
#endif
