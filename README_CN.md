# SwiftCodeBook

[English](README.md)

一个全面的 Swift 工具库与学习资源，面向 Apple 全平台开发。零外部依赖 — 完全基于 Apple 原生框架构建。

## 特性

- 适用于 iOS、macOS、tvOS、watchOS 和 visionOS 的生产级工具集
- 包含最佳实践和设计模式的教学用例
- 完整支持 Swift 6.0，包括 async/await、Actor 和 Sendable
- 全面的线程安全实现
- 零第三方依赖

## 环境要求

- Swift 6.0+
- Xcode 26+
- iOS 26.0+ / macOS 26.0+ / tvOS 26.0+ / watchOS 26.0+ / visionOS 26.0+

## 项目结构

```
SwiftCodeBook/Source/
├── Tools/
│   ├── Extension/
│   │   ├── Foundation/    # Foundation 类型扩展
│   │   ├── UIKit/         # UIKit 类型扩展
│   │   └── SwiftUI/       # SwiftUI 类型扩展
│   ├── Foundation/        # Foundation 工具类
│   └── UIKit/             # UIKit 工具类
├── UseCase/
│   ├── Foundation/        # Foundation 模式与示例
│   ├── UIKit/             # UIKit 模式与示例
│   └── SwiftUI/           # SwiftUI 模式与示例
└── Note.swift             # iOS/macOS 开发踩坑记录与最佳实践
```

## 工具集

### Foundation 扩展

| 扩展 | 功能亮点 |
|---|---|
| `Array+Tools` | 安全下标访问、JSON 转换、plist 加载、去重 |
| `String+Tools` | Range 转换（NSRange ↔ Range）、语言方向检测 |
| `Dictionary+Tools` | JSON 序列化、plist 文件加载 |
| `Date+Tools` | 日历组件、日期运算、日期比较 |
| `URL+Tools` | Query 字典解析、Query 参数操作 |
| `FileManager+Tools` | 路径快捷方式（documents、cache、tmp）、并发文件大小计算 |
| `Publisher+Tools` | Combine Publisher 工具 |
| `Task+Tools` | 结构化并发辅助工具 |
| `Data+Tools` | 数据操作工具 |
| `NSAttributedString+Tools` | 富文本辅助工具 |
| `BinaryFloatingPoint+Tools` | 浮点数工具 |
| `CGSize+Tools` | CGSize 操作工具 |

### UIKit 扩展

| 扩展 | 功能亮点 |
|---|---|
| `UIColor+Tools` | 十六进制颜色解析、RGBA 提取、十六进制生成 |
| `UIImage+Tools` | 基于颜色创建图片、方向修正、Symbol 初始化 |
| `UIView+Tools` | 视图操作与布局辅助 |
| `UIStackView+Tools` | StackView 配置工具 |

### SwiftUI 扩展

| 扩展 | 功能亮点 |
|---|---|
| `View+Tools` | `modify()`、`onSizeChange()`、`onSafeAreaInsetsChange()`、`onWindowSizeChange()`、`onInterfaceOrientationChange()` |
| `Spacer+Tools` | Spacer 工具 |

### Foundation 工具类

| 工具 | 说明 |
|---|---|
| `AnyJSONValue` | 类型擦除的 JSON 值，支持安全访问 |
| `AsyncSemaphore` | 基于 Actor 的 async/await 信号量 |
| `CancelBag` | 线程安全的 Combine 订阅管理 |
| `CurrentApplication` | 应用元信息（名称、版本、Build 号、Bundle ID、内存使用） |
| `CurrentDevice` | 设备信息（型号、系统版本、磁盘空间、模拟器检测） |
| `HashHandler` | 多算法哈希（MD5、SHA1、SHA256、SHA384、SHA512），支持流式处理 |
| `MemoryCache` | 类型安全的 NSCache 封装，支持内存警告自动清理 |
| `SerialTaskExecutor` | 基于 AsyncStream 的串行任务队列 |
| `SendablePassthroughSubject` | 线程安全的 Combine Subject |
| `WeakObject` | 泛型弱引用包装器 |
| `XMLNodeParser` | XML 解析工具 |

### UIKit 工具类

| 工具 | 说明 |
|---|---|
| `CADisplayLinkTimer` | 基于 DisplayLink 的计时器 |
| `CADisplayLinkAnimator` | 基于 DisplayLink 的动画器 |
| `GradientView` | 带 CAGradientLayer 的渐变视图 |
| `LyricHighlightingLabel` | 歌词高亮 Label |

## 用例与示例

`UseCase` 目录包含以下教学示例：

- **并发** — 结构化并发模式、Task 执行顺序、GCD
- **内存** — 指针使用、内存布局、Unsafe 操作
- **Combine** — Publisher 模式与最佳实践
- **属性包装器** — 范围限制、UserDefaults 绑定
- **KVO** — 键值观察模式
- **UIKit 模式** — 点击测试、触摸区域扩大、滚动状态检测、布局动画、阴影渲染
- **SwiftUI 模式** — NSAttributedString 转换

## 开发笔记

`Note.swift` 包含精心整理的 iOS/macOS 开发踩坑记录与最佳实践（中英双语），涵盖以下主题：

- 有符号/无符号数边界问题
- 浮点数陷阱（NaN、Infinity）
- 文件系统大小写敏感性差异
- dealloc 中的内存管理
- UIControl 与 Cell 的 selected 状态行为
- SwiftUI 视图刷新优化
- 锁的使用模式
- 更多内容...

## 许可证

MIT License

## 作者

[yuman07](https://github.com/yuman07)
