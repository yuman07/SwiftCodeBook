//
//  PodResourceBundles.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/11/8.
//

import Foundation

// 在xxx.podspec中，我们一般使用如下来定义该module独有的资源文件Bundle:
// spec.resource_bundles = { 'SwiftCodeBookResourceBundle' => ['Sources/SwiftCodeBook/**/*.{xib,storyboard,xcassets,json,mp4}'] }
// 想要获取该module的Bundle可参考下面代码
// 另外注意使用resource_bundles时，把外部资源拖到module里时，target要选该module的bundle而不是framework
private extension Bundle {
    static var swiftCodeBookBundle: Bundle? {
        guard let resourceBundleURL = Bundle.main.url(forResource: "SwiftCodeBookResourceBundle", withExtension: "bundle") else {
            return nil
        }
        return Bundle(url: resourceBundleURL)
    }
}

func testGetBundleResource() {
    guard let bundle = Bundle.swiftCodeBookBundle else { return }
    let jsonPath = bundle.path(forResource: "test", ofType: "json")
    print("\(jsonPath ?? "get failed")")
}
