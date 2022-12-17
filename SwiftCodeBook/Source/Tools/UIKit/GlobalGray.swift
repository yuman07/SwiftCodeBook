//
//  GlobalGray.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/17.
//

import UIKit

// // OC:
//- (void)openGray
//{
//    Class cls = NSClassFromString([@[@"C", @"A", @"Fi", @"lt", @"er"] componentsJoinedByString:@""]);
//    if (!(cls && [cls respondsToSelector:@selector(filterWithName:)])) {
//        return;
//    }
//
//    NSString *obj = [@[@"col", @"or", @"Sat", @"ur", @"ate"] componentsJoinedByString:@""];
//    id filter = [cls performSelector:@selector(filterWithName:) withObject:obj];
//    if (!(filter && [filter isKindOfClass:cls])) {
//        return;
//    }
//
//    [filter setValue:@0 forKey:[@[@"i", @"npu", @"t", @"Am", @"ount"] componentsJoinedByString:@""]];
//    [UIApplication sharedApplication].delegate.window.layer.filters = @[filter];
//}
//
//- (void)closeGray
//{
//    [UIApplication sharedApplication].delegate.window.layer.filters = nil;
//}

struct GlobalGray {
    static func openGray() {
        let sel = #selector(CIFilterConstructor.filter(withName:))
        guard let cls = NSClassFromString(["C", "A", "Fi", "lt", "er"].joined(separator: "")) as AnyObject as? NSObjectProtocol, cls.responds(to: sel) else { return }
        let filter = cls.perform(sel, with: ["col", "or", "Sat", "ur", "ate"].joined(separator: "")).retain().takeRetainedValue()
        filter.setValue(0, forKey: ["i", "npu", "t", "Am", "ount"].joined(separator: ""))
        UIApplication.shared.keyWindow?.layer.filters = [filter]
    }
    
    static func closeGray() {
        UIApplication.shared.keyWindow?.layer.filters = nil
    }
}
