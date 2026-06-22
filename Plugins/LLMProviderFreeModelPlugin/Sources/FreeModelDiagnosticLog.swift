import Foundation
import OSLog

/// FreeModel 供应商诊断日志（测试阶段开启，便于从 Xcode 控制台或 Console.app 复制）
enum FreeModelDiagnosticLog {
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.freemodel")

    /// 设为 `false` 可关闭详细日志（编译期常量，避免并发检查）
    static let enabled = true

    static func log(_ message: String) {
        guard enabled else { return }
        logger.notice("\(message, privacy: .public)")
        print("[FreeModel] \(message)")
    }

    static func logChunkPreview(_ label: String, data: Data) {
        guard enabled else { return }
        let preview = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(500) ?? "<non-utf8 \(data.count) bytes>"
        log("\(label) chunk(\(data.count)b): \(preview)")
    }
}
