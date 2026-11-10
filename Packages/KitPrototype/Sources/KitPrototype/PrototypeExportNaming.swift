import Foundation

/// 原型导出到 PNG 时的文件名与冲突检测。
///
/// UI 导出与 Agent 导出工具共用同一套命名与冲突判定，
/// 保证「同名文件默认不被静默覆盖」这一契约在两条路径上一致。
public enum PrototypeExportNaming {
    /// 某一屏导出后的文件名（如 `01-home.png`）。
    public static func filename(for screen: PrototypeScreen) -> String {
        String(format: "%02d-%@.png", screen.order + 1, screen.id)
    }

    /// 项目所有屏幕按顺序对应的导出文件名。
    public static func filenames(for project: PrototypeProject) -> [String] {
        project.sortedScreens.map(filename(for:))
    }

    /// 目标目录中已存在的导出文件名。
    ///
    /// - Parameters:
    ///   - directory: 导出目标目录。
    ///   - filenames: 计划写入的文件名。
    ///   - fileManager: 用于查询文件是否存在。
    public static func existingConflicts(
        in directory: URL,
        filenames: [String],
        fileManager: FileManager = .default
    ) -> [String] {
        filenames.filter { filename in
            fileManager.fileExists(atPath: directory.appendingPathComponent(filename).path)
        }
    }
}
