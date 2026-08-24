import Foundation

/// 录制文件的临时目录管理、最终落盘与异常清理。
///
/// 临时文件写入插件的 `pluginDataDirectory/ScreenRecorder/tmp/`，编码完成后再原子
/// 移动到用户指定的输出目录（默认 `~/Downloads`）。跨卷时回退为拷贝 + 删除。
public enum RecordingFileWriter {

    /// 为一次会话生成临时 `.mp4` URL。
    public static func tempURL(for sessionID: UUID, in directory: URL) -> URL {
        let tempDir = directory.appendingPathComponent("tmp", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent("\(sessionID.uuidString).mp4")
    }

    /// 把临时文件移动/拷贝到输出目录，必要时按文件名冲突追加序号。
    ///
    /// - Parameters:
    ///   - tempURL: 编码完成的临时文件。
    ///   - outputDirectory: 已校验的输出目录。
    ///   - filename: 可选文件名（不含扩展名）；缺省用 `recording-<时间戳>`。
    /// - Returns: 最终文件 URL。
    @discardableResult
    public static func finalize(
        tempURL: URL,
        to outputDirectory: URL,
        filename: String?
    ) async throws -> URL {
        try Task.checkCancellation()

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let trimmed = filename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = (trimmed?.isEmpty == false ? trimmed : nil) ?? defaultFilename()
        let destination = uniqueURL(directory: outputDirectory, baseName: baseName, extension: "mp4")

        // 同卷可直接移动；跨卷 moveItem 会抛错，回退为拷贝 + 删除。
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
        } catch {
            try FileManager.default.copyItem(at: tempURL, to: destination)
            try? FileManager.default.removeItem(at: tempURL)
        }
        return destination
    }

    /// 清理临时目录中超过 `maxAge`（默认 24 小时）的残留 `.mp4`（崩溃恢复）。
    public static func purgeStaleTempFiles(in directory: URL, maxAge: TimeInterval = 24 * 60 * 60) {
        let tempDir = directory.appendingPathComponent("tmp", isDirectory: true)
        guard let entries = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for entry in entries where entry.pathExtension.lowercased() == "mp4" {
            let modDate = try? entry.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if (modDate ?? Date.distantFuture) < cutoff {
                try? FileManager.default.removeItem(at: entry)
            }
        }
    }

    /// 删除指定临时文件（用于编码失败/取消时的回滚）。
    public static func removeTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Helpers

    private static func defaultFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "recording-\(formatter.string(from: Date()))"
    }

    /// 在 `directory` 下为 `baseName.ext` 生成不冲突的 URL（冲突时追加 -2、-3…）。
    private static func uniqueURL(directory: URL, baseName: String, extension ext: String) -> URL {
        let sanitized = sanitize(baseName)
        let first = directory.appendingPathComponent(sanitized).appendingPathExtension(ext)
        guard !FileManager.default.fileExists(atPath: first.path) else {
            var index = 2
            while true {
                let candidate = directory.appendingPathComponent("\(sanitized)-\(index)").appendingPathExtension(ext)
                if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                index += 1
            }
        }
        return first
    }

    /// 去掉文件名中非法字符。
    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?*\"<>|")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "recording" : cleaned
    }
}
