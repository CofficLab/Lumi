import Foundation
import SwiftUI
/// SwiftUI 循环调试工具
/// 用于检测和定位可能导致无限循环的 State/Binding/onChange 问题
@MainActor
final class SwiftUILoopDebugger: ObservableObject {
    static let shared = SwiftUILoopDebugger()

    /// 是否启用详细日志
    var isEnabled = true

    /// 调用栈深度限制（防止日志过多）
    private var callDepth = 0
    private let maxDepth = 10

    /// 记录最近的调用
    private var recentCalls: [(timestamp: Date, location: String, action: String)] = []
    private let maxRecentCalls = 50

    private init() {}

    /// 记录视图 body 计算
    func logBody<T: View>(view: T.Type, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        log("[BODY] \(view) body computed", location: location)
    }

    /// 记录 State 变更
    func logStateChange<T>(name: String, from: T?, to: T?, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        let fromStr = from.map { String(describing: $0) } ?? "nil"
        let toStr = to.map { String(describing: $0) } ?? "nil"
        log("[STATE] \(name): \(fromStr) → \(toStr)", location: location)
    }

    /// 记录 onChange 触发
    func logOnChange<T>(name: String, value: T, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        log("[onChange] \(name) = \(value)", location: location)
    }

    /// 记录 Binding 变更
    func logBinding<T>(name: String, value: T, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        log("[BINDING] \(name) = \(value)", location: location)
    }

    /// 记录 ObservableObject 发布
    func logPublished<T>(objectName: String, property: String, value: T, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        log("[PUBLISHED] \(objectName).\(property) = \(value)", location: location)
    }

    /// 记录 Combine sink
    func logSink<T>(publisher: String, value: T, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let location = "\(file.split(separator: "/").last ?? ""):\(line)"
        log("[SINK] \(publisher) received: \(value)", location: location)
    }

    /// 检测循环
    func detectLoop(threshold: Int = 5) -> Bool {
        let now = Date()
        let recent = recentCalls.filter { now.timeIntervalSince($0.timestamp) < 1.0 }

        // 检查是否有重复的模式
        var patternCounts: [String: Int] = [:]
        for call in recent {
            patternCounts[call.action, default: 0] += 1
        }

        for (action, count) in patternCounts {
            if count >= threshold {
                AppLogger.core.info("🔄 [LOOP DETECTED] '\(action)' triggered \(count) times in 1 second!")
                printRecentCalls()
                return true
            }
        }

        return false
    }

    /// 打印最近的调用记录
    func printRecentCalls() {
        AppLogger.core.info("📋 Recent calls (last 50):")
        for (index, call) in recentCalls.enumerated() {
            let time = String(format: "%.3f", call.timestamp.timeIntervalSince1970.truncatingRemainder(dividingBy: 1000))
            AppLogger.core.info("  [\(index)] \(time)s - \(call.location): \(call.action)")
        }
    }

    /// 清空记录
    func reset() {
        recentCalls.removeAll()
        callDepth = 0
    }

    private func log(_ action: String, location: String) {
        let timestamp = Date()
        recentCalls.append((timestamp: timestamp, location: location, action: action))

        if recentCalls.count > maxRecentCalls {
            recentCalls.removeFirst()
        }

        // 检测循环
        if detectLoop() {
            AppLogger.core.info("⚠️ Possible infinite loop detected!")
        }

        AppLogger.core.info("🐛 [SwiftUI Debug] \(location) - \(action)")
    }
}

// MARK: - 便捷宏/函数

/// 在视图 body 开始处调用，记录 body 计算
@MainActor
func debugBody<T: View>(_ view: T.Type, file: String = #file, line: Int = #line) {
    SwiftUILoopDebugger.shared.logBody(view: view, file: file, line: line)
}

/// 记录 State 变更
@MainActor
func debugStateChange<T>(name: String, from: T?, to: T?, file: String = #file, line: Int = #line) {
    SwiftUILoopDebugger.shared.logStateChange(name: name, from: from, to: to, file: file, line: line)
}

/// 记录 onChange 触发
@MainActor
func debugOnChange<T>(name: String, value: T, file: String = #file, line: Int = #line) {
    SwiftUILoopDebugger.shared.logOnChange(name: name, value: value, file: file, line: line)
}

/// 记录 Binding 变更
@MainActor
func debugBinding<T>(name: String, value: T, file: String = #file, line: Int = #line) {
    SwiftUILoopDebugger.shared.logBinding(name: name, value: value, file: file, line: line)
}
