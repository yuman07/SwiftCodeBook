//
//  ViewController.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

class ViewController: UIViewController {
    let exe = SerialTaskExecutor()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        exe.async {
            print("123")
        }
    }
}
