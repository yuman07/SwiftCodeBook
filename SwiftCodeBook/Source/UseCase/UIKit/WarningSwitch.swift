//
//  WarningSwitch.swift
//  SwiftCodeBook
//
//  Created by yuman on 2023/5/8.
//

import UIKit

// 在开发中，我们可能有这种需求：
// 当用户点击Switch时，状态先不改变，而是弹出一个警告弹窗，用户确认后才改变状态
final class WarningSwitch: UISwitch {
    
    var tapSwitchAction: (() -> Void)?
    
    lazy var cover = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        view.addGestureRecognizer(tap)
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(cover)
        
        NSLayoutConstraint.activate([
            cover.leadingAnchor.constraint(equalTo: leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: trailingAnchor),
            cover.topAnchor.constraint(equalTo: topAnchor),
            cover.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    private func tapAction() {
        tapSwitchAction?()
    }
}
