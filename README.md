<div align="center">

# SwiftCodeBook

**A comprehensive Swift utility library and learning resource for Apple platform development.**

Zero external dependencies — built entirely on Apple's native frameworks.

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS_|_macOS_|_tvOS_|_watchOS_|_visionOS-blue)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Xcode](https://img.shields.io/badge/Xcode-26+-147EFB?logo=xcode&logoColor=white)](https://developer.apple.com/xcode/)

[中文文档](README_CN.md)

</div>

---

## Highlights

- **Production-ready** utilities for iOS, macOS, tvOS, watchOS, and visionOS
- **Educational examples** demonstrating best practices and design patterns
- **Swift 6.0** with full async/await, actors, and Sendable conformance
- **Thread-safe** implementations throughout
- **Zero** third-party dependencies

## Requirements

| Requirement | Minimum Version |
|:---|:---|
| Swift | 6.0+ |
| Xcode | 26+ |
| iOS | 26.0+ |
| macOS | 26.0+ |
| tvOS | 26.0+ |
| watchOS | 26.0+ |
| visionOS | 26.0+ |

## Project Structure

```
SwiftCodeBook/Source/
├── Tools/
│   ├── Extension/
│   │   ├── Foundation/        # Extensions on Foundation types
│   │   ├── UIKit/             # Extensions on UIKit types
│   │   └── SwiftUI/           # Extensions on SwiftUI types
│   ├── Foundation/            # Foundation utility classes
│   └── UIKit/                 # UIKit utility classes
├── UseCase/
│   ├── Foundation/            # Foundation patterns & examples
│   ├── UIKit/                 # UIKit patterns & examples
│   └── SwiftUI/               # SwiftUI patterns & examples
└── Note.swift                 # Development pitfalls & best practices
```

## Utilities

<details open>
<summary><strong>Foundation Extensions</strong></summary>

| Extension | Highlights |
|:---|:---|
| `Array+Tools` | Safe subscript, JSON conversion, plist loading, duplicate removal |
| `String+Tools` | Range conversion (NSRange ↔ Range), language direction detection |
| `Dictionary+Tools` | JSON serialization, plist file loading |
| `Date+Tools` | Calendar components, date arithmetic, comparisons |
| `URL+Tools` | Query dictionary parsing, query item manipulation |
| `FileManager+Tools` | Path shortcuts (documents, cache, tmp), concurrent file size calculation |
| `Publisher+Tools` | Combine publisher utilities |
| `Task+Tools` | Structured concurrency helpers |
| `Data+Tools` | Data manipulation utilities |
| `NSAttributedString+Tools` | Attributed string helpers |
| `BinaryFloatingPoint+Tools` | Floating-point utilities |
| `CGSize+Tools` | CGSize manipulation |

</details>

<details open>
<summary><strong>UIKit Extensions</strong></summary>

| Extension | Highlights |
|:---|:---|
| `UIColor+Tools` | Hex string parsing, RGBA extraction, hex generation |
| `UIImage+Tools` | Color-based creation, orientation fix, symbol init |
| `UIView+Tools` | View manipulation and layout helpers |
| `UIStackView+Tools` | Stack view configuration |

</details>

<details open>
<summary><strong>SwiftUI Extensions</strong></summary>

| Extension | Highlights |
|:---|:---|
| `View+Tools` | `modify()`, `onSizeChange()`, `onSafeAreaInsetsChange()`, `onWindowSizeChange()`, `onInterfaceOrientationChange()` |
| `Spacer+Tools` | Spacer utilities |

</details>

<details open>
<summary><strong>Foundation Utilities</strong></summary>

| Utility | Description |
|:---|:---|
| `AnyJSONValue` | Type-erased JSON value with safe accessors |
| `AsyncSemaphore` | Actor-based async/await semaphore |
| `CancelBag` | Thread-safe Combine subscription management |
| `CurrentApplication` | App metadata (name, version, build, bundle ID, memory usage) |
| `CurrentDevice` | Device info (model, OS version, disk space, simulator detection) |
| `HashHandler` | Multi-algorithm hashing (MD5, SHA1, SHA256, SHA384, SHA512) with streaming |
| `MemoryCache` | Type-safe NSCache wrapper with memory warning cleanup |
| `SerialTaskExecutor` | AsyncStream-based serial task queue |
| `SendablePassthroughSubject` | Thread-safe Combine subject |
| `WeakObject` | Generic weak reference wrapper |
| `XMLNodeParser` | XML parsing utilities |

</details>

<details open>
<summary><strong>UIKit Utilities</strong></summary>

| Utility | Description |
|:---|:---|
| `CADisplayLinkTimer` | Display link-based timer |
| `CADisplayLinkAnimator` | Display link-based animator |
| `GradientView` | UIView with CAGradientLayer |
| `LyricHighlightingLabel` | Specialized label for lyric highlighting |

</details>

## Use Cases & Examples

The `UseCase` directory contains educational examples covering:

| Topic | Content |
|:---|:---|
| **Concurrency** | Structured concurrency patterns, Task execution order, GCD |
| **Memory** | Pointer usage, memory layout, unsafe operations |
| **Combine** | Publisher patterns and best practices |
| **Property Wrappers** | Range limiting, UserDefaults binding |
| **KVO** | Key-Value Observation patterns |
| **UIKit Patterns** | Hit testing, touch target expansion, scroll state detection, layout animations, shadow rendering |
| **SwiftUI Patterns** | NSAttributedString conversion |

## Development Notes

`Note.swift` contains a curated collection of iOS/macOS development pitfalls and best practices (bilingual Chinese/English), covering topics like:

> Signed/unsigned number edge cases, floating-point pitfalls (NaN, Infinity), file system case sensitivity, memory management in dealloc, UIControl vs Cell selected state, SwiftUI view refresh optimization, lock usage patterns, and more.

## License

This project is licensed under the [MIT License](LICENSE).

## Author

Created by [yuman07](https://github.com/yuman07)
