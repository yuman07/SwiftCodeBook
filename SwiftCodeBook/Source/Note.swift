//
//  Note.swift
//  SwiftCodeBook
//
//  Created by yuman on 2024/10/31.
//

/*
 注意以下的坑有些发生在较早的iOS版本，目前不一定成立，但可作为警示与思路
 */

/*
 OC无符号数/有符号数混用时，一定要小心
 无可避免时，先将所有整数「显式」地转为Int64再处理
 
 
 对于浮点数，要提防nan和inf这两种非法情况。判断是否正常：
 !(isinf(x) || isnan(x))
 ------
 x.isFinite
 
 
 在真机和模拟器上，文件/文件夹的大小写命名有区别，真机区分大小写，而模拟器不区分大小写
 总之要保证在同一层目录下，绝对不能有任意两个东西的name忽略大小写后相同
 
 
 Home目录下默认除了Cache和tmp这两者外，其余都会被iCloud备份
 如果需要设置某个文件夹不开启备份(该设置对于其子文件夹是递归的)：
 [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
 ------
 var values = URLResourceValues()
 values.isExcludedFromBackup = true
 try? fileURL.setResourceValues(values)
 
 
 在dealloc(以及其中调用的方法)中，需要注意一些问题：
 1) 不能使用getter去访问属性。因为若是懒加载属性，可能该属性之前还未初始化，结果在dealloc中去初始化了
 2) 不能使用一个weak指针去指向self，否则会crash(如 @weakify)
 3) 不能调用方法时将self当作参数传出去，因为若不慎被外界强持有了，销毁仍会继续，最后外界会持有一个野指针
 
 
 OC中, 不能在 @try{} 的括号内声明变量，不然一旦发生异常，会导致该变量无法释放，造成内存泄漏。
 应该在try前声明变量，然后在{}内使用即可
 
 
 对于selected属性，UIControl和Cell(UITableViewCell/UICollectionViewCell)表现是不同的。
 对于UIControl(如button)，selected的变化完全是靠代码显式设置，比如当用户点击一个button其selected值不会变化。
 但是对于cell，selected值会有自动变化的情况，可以通过增加一个关联属性xxx_selected来解决
 
 
 在tableView/collectionView中，不要在reloadData的执行过程中，又调用reloadData，会有UIBug
 比如调用reloadData后会执行cellForRowAtIndexPath，然而在这个方法中满足某个条件又执行了reloadData
 
 
 tableView/collectionView调用reloadData时，其所有cell正在执行的动画会直接跳到结束，然后所有的动画都会被清除(即便removedOnCompletion=NO)。因此最好不要在cell中执行动画，如果确实有需求，使用动图代替。
 
 
 VC使用KVO时，一般会将remove写在dealloc中，但注意此时要将add写在其init中，而非viewDidLoad。
 因为可能该VC被init后直接被销毁，没有loadView过程，导致KVO的不匹配
 
 
 tableView不执行cellForRowAtIndexPath问题：请确保要执行cellForRowAtIndexPath时，tableView的size > 0
 
 
 NSString的substringToIndex:方法，传入的index其实是长度。例如想截取一个string的前4个字，应该是
 [string substringToIndex:4];
 
 
 录制视频时，对于AVCaptureMovieFileOutput，需要设置它的movieFragmentInterval属性为kCMTimeInvalid，不然录制的视频超过10秒就会没有声音。
 
 
 在VCInit/viewDidLoad/viewWillAppear中获取屏幕宽高时要小心，可能此时应用旋转，导致想获取宽，结果得到了高。可以采用获取长短边值或者延后获取来解决
 
 
 使用Xcode12及以上的版本打包时。对于cell(UITableViewCell等)，系统会自动将其contentview置于顶层，且哪怕将其remove也会自动加回来。
 这会导致如果你直接将控件add到cell上，点击该控件将无响应，因为顶层的contentview将其拦截了。
 推荐的解法是按照苹果推荐，将子view都add到contentview上。
 或者也可以设置contentview的hidden为YES。子view仍直接放在cell上
 
 
 UIDatePicker从iOS13.4开始，会自动根据屏幕和设备类型等来调整样式。取消自动适配：
 datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
 
 
 使用自动布局设置center/centerX/centerY时一定要注意，必须使用相对坐标，而不能使用绝对坐标。
 make.centerX.equalTo(@25);   // wrong
 make.centerX.equalTo(self.view.superView.mas_left).offset(25);  // correct
 
 
 iOS9及以后，默认的英文数字字体是不等宽的，在某些情况下会造成UI问题(例如Label显示倒计时会闪动)
 label.font = [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightRegular];  // 使用系统默认的等宽字体
 
 
 比较版本号时，如果使用NSNumericSearch来比较，则会造成"1" < "1.0.0"
 
 
 OC中，如果同时重写了一个属性的getter/setter，则系统不会帮你自动声明变量，要自己加上
 @implementation ViewController {
     NSString *_testString;
 }
 
 
 UISwitch的默认size是(51, 31)，且手动修改其size是无效的
 因此如果想修改一个UISwitch的大小，只能通过修改其transfrom来实现
 这里以目标size(20, 10)为例
 sw.transform = CGAffineTransform(scaleX: 20.0 / 51.0, y: 10.0 / 31.0)
 
 
 在Swift中，避免使用some/none来命名枚举值
 
 
 在Swift中，对于空的Array或Dictionary使用is进行类型判断时要小心，都是可以通过判断的
 此时可以使用type(of:)处理
 [String]() is [Int]  // true
 [String: String]() is [Double: Int]  // true
 type(of: [String]()) == [Int].self  // false
 type(of: [String: String]()) == [Double: [String]].self // false
 
 
 设置UITextView的UITextAutocorrectionType/UITextSpellCheckingType时要注意，设置时该UITextView不能为firstResponder，否则无效果
 遇到此情况时，先要对该textView resignFirstResponder，再设置，再becomeFirstResponder
 
 
 当实现Hashable协议时，一定要保证对于两个obj：
 如果isEqual为true则hashValue一定要相同
 如果hashValue不同则isEqual一定要为false
 
 
 在Combine中，对于 @Published 的变量，在对其sink时，block内的参数值和直接访问该值是不一样的(直接访问仍是旧值)，而对于CurrentValueSubject则均为最新值
 总之一定要用sink block中的参数去获取最新值
 
 
 对于present，有几点需要注意：
 1) 不能在当前VC的viewDidLoad方法中去present下一个VC，可以在viewDidAppear或者下个Runloop
 2) 对于某个VC，对其调用dismiss方法时：
 a) 如果该VC有present的下级VC，则会dismiss掉该VC所有present的下级VC，注意自身不会被dismiss
 b) 如果该VC没有present的下级VC，且该VC自身也是被present出来的，则会dismiss掉该VC自己
 c) 如果该VC没有present的下级VC，且该VC自身不是被present出来的，则dismiss无效但completion仍会被调用
 3) 不要使用isBeingPresented属性来判断该VC是否被present出来，而应该使用presentedViewController/presentingViewController这两个属性
 presentedViewController：表示该VC present的下级VC
 presentingViewController：表示该VC被哪个VC present，即它的上级VC
 
 
 使用NSAttributedString的enumerateAttribute时，必须判断第一个参数，即value存在才能使用range，否则会用到不正确的range
 
 
 对ISO8601字符串进行Date Decode时要注意，一定要使用ISO8601DateFormatter这个专门的API，传统的DateFormatter在处理ISO8601时在某些系统的语言/时间格式下会解码失败
 
 
 通常情况下Dict的value是非可选的，此时给key赋值nil等于remove该key
 但如果该Dict的value是可选值，此时一定要注意：对于这种Dict，直接给key赋值nil，也等于直接删除该key
 如果你想要给这种Dict的某个key设置可选值为nil，需要这样操作：dict[key] = .some(nil)
 
 
 在监听键盘的通知时要注意：键盘是唯一的！
 即你的VM监听到了键盘升起，但这不代表是你的功能引发的。一定要结合你的功能的独有flag一同判断
 
 
 在使用lock.withLock{ val in ... }时要注意：
 1) 不能在{}中把val传给其他的异步方法，不然还是会有线程安全问题。你应该在异步方法中继续使用withLock来获取val
 2) {}的开始和结束必须在同一线程，最常见的错误就是{}中包裹了一个await，注意await前后极大概率不是同一个线程
 
 
 在开发中，我们有时会用Int.max这种来表示无限制
 但要注意，万一这个值后续被用于加法运算，就会因为溢出直接crash了
 总之还是尽量避免这种写法
 
 
 UITextView默认是自带padding的。如果想去掉padding，即得到一个恰好包裹住text的view，则需要设置：
 textView.contentInset = .zero
 textView.textContainerInset = .zero
 textView.textContainer.lineFragmentPadding = 0
 
 
 SwiftUI中一个view设置了cornerRadius以及contextMenu后，长按后四个角会有白色
 此时需要设置 view.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: {viewCornerRadius}))
 https://stackoverflow.com/questions/62741902/contextmenu-on-a-rounded-lineargradient-produces-sharp-edges-in-swiftui
 
 
 当用户的iOS设备在某些地区和多语言的设置下，会出现整个系统的文字行间距变大
 目前已知的复现设置为：
 地区：India
 语言：English, Hindi, Awadhi, Italian
 
 
 避免SwiftUI中多余的view刷新：
 https://fatbobman.com/zh/posts/avoid_repeated_calculations_of_swiftui_views/
 1) 当一个View实现了Equatable协议时，还必须给该view添加.equatable()，才能确保该view会通过Equatable里的方法来判断相等
 2) 对于如 @State属性(DynamicProperty)，在Equatable方法中，不需要判断其是否左右相等。因为该属性的变化一定会导致view的刷新
 3) @State属性(DynamicProperty)在赋值前先判等，确保不同再赋值
 4) 确保该 @State属性(DynamicProperty)的变化和view的变化是一一对应的。比如view有一个 @State属性 number，但是该view是判断该number的奇偶性来展示不同UI。
 那这时就会造成当number变化时，可能其奇偶性并未改变，但是view会被多余刷新。此时应该让该 @State属性为 isOdd 这样的Bool值
 
 
 AttributedString转为NSAttributedString时，如果AttributedString包含自定义的key，则转为NSAttributedString后会丢失
 
 
 当我们给UITextView/UILabel设置attributedText属性时要注意，iOS内部会自动对我们传入的attributedText进行调整。
 导致我们赋值的attributedText和之后我们从textView.attributedText获取的attributedText不相等(即isEqual为false)
 此时可以给textView添加一个rawAttributedText之类的属性，用这个来进行比较。这样就稳定了
 
 
 在Combine中对Publisher获取value时，应该使用传统的sink而不要使用await.
 使用await会导致某些情况下无法正确获取所有的更新
 
 */


/*
 https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md (Implementation note)
 对于actor，当多个task await同一个actor时，最终执行的顺序不一定是它们当初等待的顺序
 如果需要严格的FIFO，请使用Queue
 */


/*
 更换APP启动图：
 
 以下仅针对使用'storyboard'来管理启动图的情况
 
 更换app启动图，主要有两种需求：
 1 每次发版时，更换新的启动图。
 2 无需发版，可热更换启动图
 
 对于第二点，可以参考百度的文章：
 https://mp.weixin.qq.com/s/PXKJ0_ETGtw_m0BmD7sZ4A
 
 对于第一点，看上去只需要替换本地图片即可，但是实际操作会发现大量不更新，白屏，黑屏等问题。
 这里讲一下注意点：
 1) 启动图片，必须采用直接放在工程里的管理方式，即不能放在assets里面
 2) 启动图片拖入工程时，必须勾选'Copy items if needed' 和 'Create groups'这两项
 3) 启动图片必须均为png格式，即后缀为.png，且保证实际格式也为png
 4) 更新启动图时，必须同时更新图片名。例如之前的图片名为launch.png，那么这次新图可改名为launch_v1.png这种
 以上四点必须全部满足，不然会有各种奇怪问题。。。
 */
