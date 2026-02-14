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
        let aa = NSAttributedString(string: "  \n 123😄2344  \n")
        print(aa.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
