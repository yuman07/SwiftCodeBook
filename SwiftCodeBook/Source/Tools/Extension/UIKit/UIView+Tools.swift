//
//  UIView+Tools.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

#if os(iOS) || os(tvOS) || os(visionOS)
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
    
    var interfaceOrientation: UIInterfaceOrientation {
        window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .unknown
    }
}

public extension UIView {
    var parentWindowPublisher: AnyPublisher<UIWindow?, Never> {
        let subject = CurrentValueSubject<UIWindow?, Never>(nil)
        
        DispatchQueue.dispatchToMainIfNeeded { [weak self] in
            guard let self else { return }
            subject.send(window)
            
            let observer: WindowObserverView
            if let windowObserverView = subviews.compactMap({ $0 as? WindowObserverView }).first {
                observer = windowObserverView
            } else {
                let windowObserverView = WindowObserverView()
                addSubview(windowObserverView)
                observer = windowObserverView
            }
            
            observer.$parentWindow
                .sink { subject.send($0) }
                .store(in: observer.cancelBag)
        }
        
        return subject
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var parentWindowSizePublisher: AnyPublisher<CGSize?, Never> {
        parentWindowPublisher
            .flatMap({ window -> AnyPublisher<CGSize?, Never> in
                guard let window else { return Just(nil).eraseToAnyPublisher() }
                return window.publisher(for: \.frame).map(\.size).eraseToAnyPublisher()
            })
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var interfaceOrientationPublisher: AnyPublisher<UIInterfaceOrientation, Never> {
        parentWindowPublisher
            .flatMap({ window -> AnyPublisher<UIInterfaceOrientation, Never> in
                guard let windowScene = window?.windowScene else { return Just(.unknown).eraseToAnyPublisher() }
                return windowScene.publisher(for: \.effectiveGeometry).map(\.interfaceOrientation).eraseToAnyPublisher()
            })
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var userInterfaceSizeClassPublisher: AnyPublisher<(horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass), Never> {
        let subject = CurrentValueSubject<(horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass), Never>((.unspecified, .unspecified))
        
        DispatchQueue.dispatchToMainIfNeeded { [weak self] in
            guard let self else { return }
            subject.send((traitCollection.horizontalSizeClass, traitCollection.verticalSizeClass))
            _ = registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (view: Self, _) in
                subject.send((view.traitCollection.horizontalSizeClass, view.traitCollection.verticalSizeClass))
            }
        }
        
        return subject
            .removeDuplicates { $0.horizontal == $1.horizontal && $0.vertical == $1.vertical }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    var userInterfaceStylePublisher: AnyPublisher<UIUserInterfaceStyle, Never> {
        let subject = CurrentValueSubject<UIUserInterfaceStyle, Never>(.unspecified)
        
        DispatchQueue.dispatchToMainIfNeeded { [weak self] in
            guard let self else { return }
            subject.send(traitCollection.userInterfaceStyle)
            _ = registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
                subject.send(view.traitCollection.userInterfaceStyle)
            }
        }
        
        return subject
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

private final class WindowObserverView: UIView {
    @Published var parentWindow: UIWindow?
    let cancelBag = CancelBag()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init() {
        super.init(frame: .zero)
        isHidden = true
        backgroundColor = .clear
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        parentWindow = window
    }
}
#endif
