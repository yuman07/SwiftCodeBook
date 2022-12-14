//
//  ScreenRotate.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/11/25.
//

import UIKit

class ScreenRotateViewController: UIViewController {
    // screen rotate callback
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        // will rotate here
        
        coordinator.animate(alongsideTransition: nil) { _ in
            // rotate finish here
        }
    }
}
