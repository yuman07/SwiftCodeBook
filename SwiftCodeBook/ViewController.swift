//
//  ViewController.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        DispatchQueue.global().async {
            GlobalGray.openGray()
        }
    }
}
