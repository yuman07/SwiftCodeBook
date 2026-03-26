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
            Text("Hello, world!").padding()
            let _ = DispatchQueue.main.async {
                tester.testSwiftCodeBookApp()
            }
        }
    }
}

@MainActor
final class TestSwiftCodeBookApp {
    func testSwiftCodeBookApp() {
        // code here
    }
}
