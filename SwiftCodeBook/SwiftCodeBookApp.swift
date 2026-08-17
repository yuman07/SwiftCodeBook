//
//  SwiftCodeBookApp.swift
//  SwiftCodeBook
//
//  Created by yuman on 2026/3/26.
//

import SwiftUI

@main
struct SwiftCodeBookApp: App {
    let tester = TestSwiftCodeBookApp()
    
    var body: some Scene {
        WindowGroup {
            Text("Hello, world!")
                .padding()
                .task { tester.testSwiftCodeBookApp() }
        }
    }
}

@MainActor
final class TestSwiftCodeBookApp {
    func testSwiftCodeBookApp() {
        // code here
        
        var uuu = URLComponents()
        uuu.scheme = "https"
        uuu.host = "www.baidu.com"
        uuu.percentEncodedQuery = "id=2/+3"
        print(uuu.url!)
    }
}
