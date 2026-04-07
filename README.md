# SwiftCodeBook

[中文文档](README_CN.md)

A comprehensive Swift utility library and learning resource for Apple platform development. Zero external dependencies — built entirely on Apple's native frameworks.

## Features

- Production-ready utilities for iOS, macOS, tvOS, watchOS, and visionOS
- Educational use-case examples demonstrating best practices and patterns
- Full Swift 6.0 support with async/await, actors, and Sendable conformance
- Thread-safe implementations throughout
- Zero third-party dependencies

## Requirements

- Swift 6.0+
- Xcode 16+
- iOS 26.0+ / macOS 26.0+ / tvOS 26.0+ / watchOS 26.0+ / visionOS 26.0+

## Project Structure

```
SwiftCodeBook/Source/
├── Tools/
│   ├── Extension/
│   │   ├── Foundation/    # Extensions on Foundation types
│   │   ├── UIKit/         # Extensions on UIKit types
│   │   └── SwiftUI/       # Extensions on SwiftUI types
│   ├── Foundation/        # Foundation utility classes
│   └── UIKit/             # UIKit utility classes
├── UseCase/
│   ├── Foundation/        # Foundation patterns & examples
│   ├── UIKit/             # UIKit patterns & examples
│   └── SwiftUI/           # SwiftUI patterns & examples
└── Note.swift             # iOS/macOS development pitfalls & best practices
```

## Utilities

### Foundation Extensions

| Extension | Highlights |
|---|---|
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

### UIKit Extensions

| Extension | Highlights |
|---|---|
| `UIColor+Tools` | Hex string parsing, RGBA extraction, hex generation |
| `UIImage+Tools` | Color-based creation, orientation fix, symbol init |
| `UIView+Tools` | View manipulation and layout helpers |
| `UIStackView+Tools` | Stack view configuration |

### SwiftUI Extensions

| Extension | Highlights |
|---|---|
| `View+Tools` | `modify()`, `onSizeChange()`, `onSafeAreaInsetsChange()`, `onWindowSizeChange()`, `onInterfaceOrientationChange()` |
| `Spacer+Tools` | Spacer utilities |

### Foundation Utilities

| Utility | Description |
|---|---|
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

### UIKit Utilities

| Utility | Description |
|---|---|
| `CADisplayLinkTimer` | Display link-based timer |
| `CADisplayLinkAnimator` | Display link-based animator |
| `GradientView` | UIView with CAGradientLayer |
| `LyricHighlightingLabel` | Specialized label for lyric highlighting |

## Use Cases & Examples

The `UseCase` directory contains educational examples covering:

- **Concurrency** — Structured concurrency patterns, Task execution order, GCD
- **Memory** — Pointer usage, memory layout, unsafe operations
- **Combine** — Publisher patterns and best practices
- **Property Wrappers** — Range limiting, UserDefaults binding
- **KVO** — Key-Value Observation patterns
- **UIKit Patterns** — Hit testing, touch target expansion, scroll state detection, layout animations, shadow rendering
- **SwiftUI Patterns** — NSAttributedString conversion

## Development Notes

`Note.swift` contains a curated collection of iOS/macOS development pitfalls and best practices (bilingual Chinese/English), covering topics like:

- Signed/unsigned number edge cases
- Floating-point pitfalls (NaN, Infinity)
- File system case sensitivity
- Memory management in dealloc
- UIControl vs Cell selected state
- SwiftUI view refresh optimization
- Lock usage patterns
- And more

## License

MIT License

## Author

[yuman07](https://github.com/yuman07)
