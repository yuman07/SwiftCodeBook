//
//  ViewController.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/10/26.
//

import UIKit

let json = """
{
    "ext": {
        "id": 1234,
        "name": "yuman",
        "length": "789.56",
        "array": ["1", 2, 3.3, ["4", {"A1": "哈哈"}]],
        "attribute": {
            "h1": "👌🏻",
            "h2": 111,
            "h3": {
                "p1": "你好",
                "p2": ["地球", "火星"],
                "p3": null,
                "p4": true,
                "p5": []
            },
            "h4": {}
        }
    }
}
"""

struct JSONItem: Codable {
    let ext: JSONDictionaryCodable
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        if case let item = JSONItem(JSONString: json), let res = item?.ext.value {
            if let jj = res.toJSONString() {
                print(jj)
            }
        }
        print("fin")
    }
}
