//
//  WillDidMove.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/4/15.
//

import UIKit

// 当一个VC在navStack中时，当从该VC push到另一个VC，会调用viewWill/DidAppear方法，我们有时会在里面做一些清理操作
// 但此时该VC其实仍在navStack中并未释放，我们可能希望是该VC被pop时才做这些清理操作
// willMove/didMove可以满足这个时机
final class SampleWillDidMoveViewController: UIViewController {
    
    // 将要被push/pop时被调用
    override func willMove(toParent parent: UIViewController?) {
        // (parent == nil)说明此时是被pop出navStack
        if parent == nil {
            print("willMove: parent is nil")
            print("willMove: navStack \(String(describing: navigationController))")
        } else {
            // (parent != nil)说明此时是被push到navStack
            print("willMove: parent \(String(describing: parent))")
            print("willMove: navStack \(String(describing: navigationController))")
        }
    }
    
    // push/pop完成时被调用
    override func didMove(toParent parent: UIViewController?) {
        // (parent == nil)说明此时是被pop出navStack
        if parent == nil {
            print("didMove: parent is nil")
            print("didMove: navStack \(String(describing: navigationController))")
        } else {
            // (parent != nil)说明此时是被push到navStack
            print("didMove: parent \(String(describing: parent))")
            print("didMove: navStack \(String(describing: navigationController))")
        }
    }
}

