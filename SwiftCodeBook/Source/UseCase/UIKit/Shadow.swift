//
//  Shadow.swift
//  SwiftCodeBook
//
//  Created by yuman on 2022/12/14.
//

import UIKit

class shadowViewController: UIViewController {
    private let contentView = UIView(frame: CGRect(x: 100, y: 100, width: 100, height: 200))
    private let shadowView = UIView(frame: CGRect(x: 100, y: 100, width: 100, height: 200))
    
    // example: add shadow to contentView
    func shadowNormal() {
        // 注意有阴影的view不能是透明的。
        contentView.backgroundColor = .white
        
        // 阴影的颜色。必须设置，注意是CGColor
        contentView.layer.shadowColor = UIColor.black.cgColor
        
        // 阴影的透明度，范围是[0, 1]，默认值为0即不显示
        // 必须手动设置为大于0的值
        contentView.layer.shadowOpacity = 1.0
        
        // 阴影的偏移量，注意偏移方向和UIKit方向相同
        // 这句话即分别向右和上偏移3pt
        contentView.layer.shadowOffset = CGSize(width: 3, height: -3)
        
        // 阴影的模糊半径，默认值为3。该值越大阴影的模糊效果越强
        // 如果UE使用的是sketch，则其阴影属性中的(blur/2)即为这里的shadowRadius
        contentView.layer.shadowRadius = 10
        
        // 阴影路径
        // 注意：不设置该项阴影也可以正常展示，但会造成离屏渲染。设置该项可以提升性能
        // 一般该rect和阴影view的bounds一致即可，但如果UE使用的是sketch，则还需要根据其spread值进行调整
        // rect = contentView.bounds.insetBy(dx: -spread, dy: -spread)
        let rect = contentView.bounds.insetBy(dx: -4, dy: -4)
        contentView.layer.shadowPath = UIBezierPath(rect: rect).cgPath
    }
    
    func shadowWhenClipsToBounds() {
        // 如果contentView没有设置clipsToBounds/masksToBounds为true，那么按照shadowNormal()的代码设置即可
        // 但如果contentView有设置，则需要按照如下代码
        // contentView即实际放东西的view，但外面需要包一层shadowView
        // 和阴影有关的属性统统在shadowView上设置
        let contentView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 200))
        view.addSubview(shadowView)
        shadowView.addSubview(contentView)
        
        /// 对shadowView设置阴影属性...(省略)
        shadowView.layer.shadowColor = nil
        
        /// 对contentView设置masksToBounds为YES
        contentView.layer.masksToBounds = true
    }
}
