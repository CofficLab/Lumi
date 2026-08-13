import SwiftUI

// MARK: - 跨平台图像 / 剪贴板适配
//
// 把 AppKit(`NSImage`/`NSPasteboard`) 与 UIKit(`UIImage`/`UIPasteboard`) 的差异
// 收口到本文件，LumiUI 其余源码只依赖这里的平台无关 API，从而可以同时编译到
// macOS 与 iOS。

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
/// 跨平台图像类型：macOS 用 `NSImage`。
public typealias LumiPlatformImage = NSImage

public extension Image {
    /// 从跨平台图像构造 SwiftUI `Image`。
    init(lumiImage image: LumiPlatformImage) {
        self.init(nsImage: image)
    }
}
#elseif canImport(UIKit)
/// 跨平台图像类型：iOS 用 `UIImage`。
public typealias LumiPlatformImage = UIImage

public extension Image {
    /// 从跨平台图像构造 SwiftUI `Image`。
    init(lumiImage image: LumiPlatformImage) {
        self.init(uiImage: image)
    }
}
#endif

/// 跨平台剪贴板写入。
public enum LumiPasteboard {
    /// 将字符串复制到系统剪贴板。
    public static func copyString(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #elseif canImport(UIKit)
        UIPasteboard.general.string = string
        #endif
    }
}

// MARK: - 跨平台语义色

public extension Color {
    /// 跨平台"控件背景"语义色（macOS=`.controlBackgroundColor`，iOS=`.secondarySystemBackground`）。
    static var lumiControlBackground: Color {
        #if canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #elseif canImport(UIKit)
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// 跨平台"文本背景"语义色（macOS=`.textBackgroundColor`，iOS=`.systemBackground`）。
    static var lumiTextBackground: Color {
        #if canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #elseif canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #endif
    }
}

public extension LumiPlatformImage {
    /// 从文件 URL 加载图像（macOS=`NSImage(contentsOf:)`，iOS=`UIImage(contentsOfFile:)`）。
    convenience init?(lumiContentsOf url: URL) {
        #if canImport(AppKit)
        self.init(contentsOf: url)
        #elseif canImport(UIKit)
        self.init(contentsOfFile: url.path)
        #endif
    }
}
