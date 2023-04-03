//
//  AutoLayoutDoAnimation.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/17.
//

import UIKit

final class AutoLayoutDoAnimationVC: UIViewController {
    
    let someView = {
        let view = UIView()
        view.backgroundColor = .red
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        setupUI()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.doAnimation()
        }
    }
    
    func setupUI() {
        view.addSubview(someView)
        
        NSLayoutConstraint.activate([
            someView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            someView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 50),
            someView.widthAnchor.constraint(equalToConstant: 100),
            someView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    func doAnimation() {
        let constraints = someView.constraints + (someView.superview?.constraints ?? [])
        guard let topCon = constraints.first(where: { $0.firstAnchor == someView.topAnchor }),
              let leftCon = constraints.first(where: { $0.firstAnchor == someView.leftAnchor })
        else { return }
        
        UIView.animate(withDuration: 0.5) { [weak self] in
            guard let self else { return }
            topCon.constant = 100
            leftCon.constant = 200
            someView.superview?.layoutIfNeeded()
        }
    }
}
