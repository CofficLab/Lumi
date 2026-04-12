import AppKit
import SwiftUI

/// Git Commit Detail 服务
///
/// 承担 GitCommitDetailView 中的无状态逻辑，包括：
/// - 日期格式化
/// - 文件图标/颜色映射
/// - 复制 Hash 到剪贴板
/// - 加载 Commit 详情、工作区变更、文件 Diff 的数据获取
enum GitCommitDetailService {
    // MARK: - Date Formatting

    /// 将日期字符串（多种 ISO 格式）统一格式化为 "yyyy-MM-dd HH:mm:ss"
    static func formattedDate(_ dateString: String) -> String {
        let formatters = DateParseHelper.formatHandlers

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                displayFormatter.locale = Locale(identifier: "en_US_POSIX")
                return displayFormatter.string(from: date)
            }
        }

        return dateString
    }

    // MARK: - File Icon

    /// 根据文件扩展名返回 SF Symbol 图标名称
    static func fileIcon(for file: String) -> String {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "ts", "jsx", "tsx": return "doc.text.fill"
        case "json": return "braces"
        case "md", "markdown": return "doc.text"
        case "yml", "yaml": return "doc.text"
        case "plist": return "gearshape"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "xcodeproj", "xcworkspace": return "hammer"
        case "html", "css": return "globe"
        case "py": return "doc.text.fill"
        case "rb": return "doc.text.fill"
        case "go": return "doc.text.fill"
        case "rs": return "doc.text.fill"
        default: return "doc.text"
        }
    }

    /// 根据文件扩展名返回图标颜色
    static func fileIconColor(for file: String) -> Color {
        let ext = (file as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts": return .yellow
        case "json": return .green
        case "md": return .blue
        default: return .secondary
        }
    }

    // MARK: - Clipboard

    /// 将 commit hash 复制到系统剪贴板
    static func copyHash(_ hash: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hash, forType: .string)
        #endif
    }

    // MARK: - Load Commit Detail

    /// 加载指定 commit 的详情和变更文件列表
    ///
    /// - Parameters:
    ///   - path: 项目路径
    ///   - hash: Commit Hash
    /// - Returns: (commit 详情, 变更文件列表)
    static func loadCommitDetail(path: String, hash: String) async throws -> (GitCommitDetail, [GitChangedFile]) {
        async let detailTask = GitService.shared.getCommitDetail(path: path, hash: hash)
        async let filesTask = Task.detached(priority: .userInitiated) {
            try GitService.shared.getCommitChangedFiles(path: path, hash: hash)
        }

        let detail = try await detailTask
        let files = (try? await filesTask.value) ?? []
        return (detail, files)
    }

    // MARK: - Load Working State

    /// 加载未提交变更的文件列表
    ///
    /// - Parameter path: 项目路径
    /// - Returns: 变更文件列表
    static func loadUncommittedFiles(path: String) async throws -> [GitChangedFile] {
        try await GitService.shared.getUncommittedChanges(path: path)
    }

    // MARK: - Load File Diff

    /// 加载指定文件的 diff 内容
    ///
    /// - Parameters:
    ///   - file: 文件路径
    ///   - projectPath: 项目路径
    ///   - commitHash: 若为 nil 则加载未提交变更的 diff，否则加载指定 commit 的 diff
    /// - Returns: (旧文本, 新文本)
    static func loadFileDiff(file: String, projectPath: String, commitHash: String?) async throws -> (String, String) {
        if let hash = commitHash {
            let (before, after) = try await GitService.shared.getCommitFileContentChange(
                path: projectPath,
                hash: hash,
                file: file
            )
            return (before ?? "", after ?? "")
        } else {
            let (before, after) = try await GitService.shared.getUncommittedFileContentChange(
                path: projectPath,
                file: file
            )
            return (before ?? "", after ?? "")
        }
    }
}
