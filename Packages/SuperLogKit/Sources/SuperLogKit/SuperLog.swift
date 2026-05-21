import Foundation
import SwiftUI

/// 提供统一的日志记录和调试信息格式化功能的协议
///
/// `SuperLog` 协议为应用程序提供了一致的日志记录格式和调试信息输出功能。
/// 它支持自动生成 emoji 标识、线程信息显示，以及统一的日志前缀格式。
///
/// ## 使用示例:
/// ```swift
/// class UserManager: SuperLog {
///     static var emoji: String { "👤" }  // 自定义 emoji
///
///     func login() {
///         print("\(t)开始登录处理") // 输出带有线程信息和标识的日志
///
///         if isMain {
///             print("\(t)在主线程执行")
///         }
///
///         // 使用原因标记
///         print("\(t)登录失败\(r("密码错误"))")
///     }
/// }
///
/// // 输出示例:
/// // [UI] | 👤 UserManager           | 开始登录处理
/// // [UI] | 👤 UserManager           | 在主线程执行
/// // [UI] | 👤 UserManager           | 登录失败 ➡️ 密码错误
/// ```
public protocol SuperLog {
    /// 获取实现者的标识 emoji
    static var emoji: String { get }

    /// 获取带有线程信息的完整前缀
    static var t: String { get }

    /// 获取实现者的类型名称
    static var author: String { get }
}

public extension SuperLog {
    // MARK: - Static Properties

    /// 如果实现者没有提供 emoji，则根据 author 生成默认 emoji
    static var emoji: String {
        return Self.author.generateContextEmoji()
    }

    /// 获取当前线程的质量描述和 emoji
    static var t: String {
        let emoji = Self.emoji
        let qosDesc = Thread.currentQosDescription
        return "\(qosDesc) | \(emoji) \(author.padding(toLength: 27, withPad: " ", startingAt: 0)) | "
    }

    /// 获取实现者的作者名称
    static var author: String {
        let fullName = String(describing: Self.self)
        return fullName.split(separator: "<").first.map(String.init) ?? fullName
    }

    // MARK: - Instance Properties

    /// 获取实现者的作者名称
    var author: String { Self.author }

    /// 获取实现者的类名
    var className: String { author }

    /// 判断当前线程是否为主线程
    var isMain: Bool { Thread.isMainThread }

    /// 获取当前线程的质量描述和 emoji
    var t: String { Self.t }

    // MARK: - Instance Methods

    /// 生成带有原因的字符串
    /// - Parameter s: 原始字符串
    /// - Returns: 带有原因的字符串
    func r(_ s: String) -> String { makeReason(s) }

    /// 生成原因字符串
    /// - Parameter s: 原始字符串
    /// - Returns: 生成的原因字符串
    func makeReason(_ s: String) -> String { " ➡️ " + s }

    // MARK: - Static Methods

    /// 获取实现者的 onAppear 字符串
    static var onAppear: String { "\(t)📺 OnAppear " }

    /// 适用于表示初始化的场景，如 View 的 init 方法
    static var onInit: String { "\(t)🚩 Init " }

    // MARK: - Static Properties for Instance Methods

    /// 获取实现者的 a 字符串
    var a: String { Self.a }

    /// 获取实现者的 i 字符串
    var i: String { Self.i }

    /// 获取实现者的 a 字符串
    static var a: String { Self.onAppear }

    /// 获取实现者的 i 字符串
    static var i: String { Self.onInit }
}

/// Thread 类型的扩展，提供线程服务质量相关的功能
public extension Thread {
    /// 获取当前线程的服务质量(QoS)描述字符串
    ///
    /// 返回当前线程的服务质量级别的描述，不包含名称部分，只返回对应的标识符
    ///
    /// ## 返回值示例:
    /// - 主线程: "[UI]"
    /// - 用户交互线程: "[UI]"
    /// - 用户发起线程: "[IN]"
    /// - 默认线程: "[DF]"
    /// - 实用工具线程: "[UT]"
    /// - 后台线程: "[BG]"
    /// - 未指定: "[UN]"
    ///
    /// ## 使用示例:
    /// ```swift
    /// // 在任意线程中获取当前线程的QoS描述
    /// let qosDesc = Thread.currentQosDescription
    /// print("当前线程: \(qosDesc)") // 例如输出: "当前线程: [BG]"
    /// ```
    static var currentQosDescription: String {
        current.qualityOfService.description(withName: false)
    }
}

/// QualityOfService 的扩展，提供描述字符串生成功能
public extension QualityOfService {
    /// 获取服务质量级别的描述字符串
    ///
    /// - Parameters:
    ///   - withName: 是否包含名称部分，默认为 true
    /// - Returns: 服务质量级别的描述字符串
    ///
    /// ## 描述格式:
    /// - withName = true: "[UI] userInteractive"
    /// - withName = false: "[UI]"
    func description(withName: Bool = true) -> String {
        switch self {
        case .userInteractive:
            return withName ? "[UI] userInteractive" : "[UI]"
        case .userInitiated:
            return withName ? "[IN] userInitiated" : "[IN]"
        case .default:
            return withName ? "[DF] default" : "[DF]"
        case .utility:
            return withName ? "[UT] utility" : "[UT]"
        case .background:
            return withName ? "[BG] background" : "[BG]"
        @unknown default:
            return withName ? "[UN] unspecified" : "[UN]"
        }
    }
}

/// String 类型的扩展，提供上下文 emoji 生成功能
public extension String {
    /// 为字符串生成上下文相关的 emoji
    ///
    /// 根据字符串中的关键词自动生成对应的 emoji 表情符号
    ///
    /// ## 使用示例:
    /// ```swift
    /// print("UserManager".generateContextEmoji())  // "👤"
    /// print("DatabaseService".generateContextEmoji()) // "🗄️"
    /// print("NetworkManager".generateContextEmoji()) // "🌐"
    /// ```
    var withContextEmoji: String {
        let lowercased = self.lowercased()

        // User & Authentication
        if lowercased.contains("user") || lowercased.contains("account") {
            return "👤 \(self)"
        }
        if lowercased.contains("login") || lowercased.contains("auth") {
            return "🔐 \(self)"
        }

        // Data & Storage (specific before general)
        if lowercased.contains("database") || lowercased.contains("db") || lowercased.contains("storage") {
            return "🗄️ \(self)"
        }
        if lowercased.contains("cache") {
            return "💾 \(self)"
        }
        if lowercased.contains("data") || lowercased.contains("model") || lowercased.contains("entity") {
            return "📦 \(self)"
        }

        // Network
        if lowercased.contains("network") || lowercased.contains("network") || lowercased.contains("api") {
            return "🌐 \(self)"
        }
        if lowercased.contains("download") {
            return "⬇️ \(self)"
        }
        if lowercased.contains("upload") {
            return "⬆️ \(self)"
        }

        // UI & View
        if lowercased.contains("view") || lowercased.contains("component") {
            return "🎨 \(self)"
        }
        if lowercased.contains("window") {
            return "🪟 \(self)"
        }
        if lowercased.contains("button") {
            return "🔘 \(self)"
        }

        // Files & Documents
        if lowercased.contains("file") {
            return "📄 \(self)"
        }
        if lowercased.contains("document") || lowercased.contains("doc") {
            return "📝 \(self)"
        }
        if lowercased.contains("image") || lowercased.contains("photo") || lowercased.contains("picture") {
            return "🖼️ \(self)"
        }

        // Editor & Code
        if lowercased.contains("editor") || lowercased.contains("edit") {
            return "✏️ \(self)"
        }
        if lowercased.contains("code") || lowercased.contains("syntax") {
            return "💻 \(self)"
        }
        if lowercased.contains("project") {
            return "📁 \(self)"
        }

        // Settings & Configuration
        if lowercased.contains("setting") || lowercased.contains("config") || lowercased.contains("preference") {
            return "⚙️ \(self)"
        }
        if lowercased.contains("theme") {
            return "🎭 \(self)"
        }

        // Actions & Events (checked before manager/service/handler)
        if lowercased.contains("action") || lowercased.contains("command") {
            return "⚡ \(self)"
        }
        if lowercased.contains("event") || lowercased.contains("observer") {
            return "📡 \(self)"
        }

        // Errors & Warnings (checked before manager/service/handler)
        if lowercased.contains("error") {
            return "❌ \(self)"
        }
        if lowercased.contains("warning") {
            return "⚠️ \(self)"
        }

        // Search & Navigation
        if lowercased.contains("search") || lowercased.contains("find") {
            return "🔍 \(self)"
        }
        if lowercased.contains("navigation") || lowercased.contains("nav") {
            return "🧭 \(self)"
        }

        // Time & Date
        if lowercased.contains("time") || lowercased.contains("date") || lowercased.contains("calendar") {
            return "🕐 \(self)"
        }

        // Communication (checked before manager/service/handler)
        if lowercased.contains("chat") || lowercased.contains("message") {
            return "💬 \(self)"
        }
        if lowercased.contains("notification") || lowercased.contains("notify") {
            return "🔔 \(self)"
        }

        // System & Hardware
        if lowercased.contains("system") || lowercased.contains("os") {
            return "⚙️ \(self)"
        }
        if lowercased.contains("device") || lowercased.contains("hardware") {
            return "📱 \(self)"
        }

        // Development & Debug (checked before manager/service/handler)
        if lowercased.contains("debug") || lowercased.contains("log") {
            return "🐛 \(self)"
        }
        if lowercased.contains("test") {
            return "🧪 \(self)"
        }

        // Tools & Utilities (general - checked last)
        if lowercased.contains("manager") || lowercased.contains("service") || lowercased.contains("handler") {
            return "🛠️ \(self)"
        }
        if lowercased.contains("helper") || lowercased.contains("util") {
            return "🧰 \(self)"
        }

        // Default
        return "📌 \(self)"
    }

    /// 为字符串生成上下文相关的 emoji（简化版）
    ///
    /// - Returns: 生成的 emoji
    func generateContextEmoji() -> String {
        let lowercased = self.lowercased()

        // User & Authentication
        if lowercased.contains("user") || lowercased.contains("account") { return "👤" }
        if lowercased.contains("login") || lowercased.contains("auth") { return "🔐" }

        // Data & Storage (specific before general)
        if lowercased.contains("database") || lowercased.contains("db") || lowercased.contains("storage") { return "🗄️" }
        if lowercased.contains("cache") { return "💾" }
        if lowercased.contains("data") || lowercased.contains("model") || lowercased.contains("entity") { return "📦" }

        // Network
        if lowercased.contains("network") || lowercased.contains("network") || lowercased.contains("api") { return "🌐" }
        if lowercased.contains("download") { return "⬇️" }
        if lowercased.contains("upload") { return "⬆️" }

        // UI & View
        if lowercased.contains("view") || lowercased.contains("component") { return "🎨" }
        if lowercased.contains("window") { return "🪟" }
        if lowercased.contains("button") { return "🔘" }

        // Files & Documents
        if lowercased.contains("file") { return "📄" }
        if lowercased.contains("document") || lowercased.contains("doc") { return "📝" }
        if lowercased.contains("image") || lowercased.contains("photo") || lowercased.contains("picture") { return "🖼️" }

        // Editor & Code
        if lowercased.contains("editor") || lowercased.contains("edit") { return "✏️" }
        if lowercased.contains("code") || lowercased.contains("syntax") { return "💻" }
        if lowercased.contains("project") { return "📁" }

        // Settings & Configuration
        if lowercased.contains("setting") || lowercased.contains("config") || lowercased.contains("preference") { return "⚙️" }
        if lowercased.contains("theme") { return "🎭" }

        // Actions & Events (checked before manager/service/handler)
        if lowercased.contains("action") || lowercased.contains("command") { return "⚡" }
        if lowercased.contains("event") || lowercased.contains("observer") { return "📡" }

        // Errors & Warnings (checked before manager/service/handler)
        if lowercased.contains("error") { return "❌" }
        if lowercased.contains("warning") { return "⚠️" }

        // Search & Navigation
        if lowercased.contains("search") || lowercased.contains("find") { return "🔍" }
        if lowercased.contains("navigation") || lowercased.contains("nav") { return "🧭" }

        // Time & Date
        if lowercased.contains("time") || lowercased.contains("date") || lowercased.contains("calendar") { return "🕐" }

        // Communication (checked before manager/service/handler)
        if lowercased.contains("chat") || lowercased.contains("message") { return "💬" }
        if lowercased.contains("notification") || lowercased.contains("notify") { return "🔔" }

        // System & Hardware
        if lowercased.contains("system") || lowercased.contains("os") { return "⚙️" }
        if lowercased.contains("device") || lowercased.contains("hardware") { return "📱" }

        // Development & Debug (checked before manager/service/handler)
        if lowercased.contains("debug") || lowercased.contains("log") { return "🐛" }
        if lowercased.contains("test") { return "🧪" }

        // Tools & Utilities (general - checked last)
        if lowercased.contains("manager") || lowercased.contains("service") || lowercased.contains("handler") { return "🛠️" }
        if lowercased.contains("helper") || lowercased.contains("util") { return "🧰" }

        // Default
        return "📌"
    }
}
