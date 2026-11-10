import Foundation

/// GUI 导出的目标文件规划。
///
/// GUI 导出的文件名完全由简历 ID 与页码决定，重复导出到同一目录必然同名；
/// 因此写入前先一次性算出全部目标并检测冲突，避免静默覆盖用户已有文件。
enum ResumeExportTargets {
    /// 本次导出将写入的文件名，顺序与写入顺序一致。
    static func fileNames(resumeID: String, pageCount: Int, pngOnly: Bool) -> [String] {
        var names: [String] = []
        if !pngOnly {
            names.append("\(resumeID).pdf")
        }
        for pageIndex in 0..<max(0, pageCount) {
            names.append(String(format: "%@-p%02d.png", resumeID, pageIndex + 1))
        }
        return names
    }

    /// 目标目录中已存在的目标文件；非空表示写入前必须取得覆盖授权。
    static func existingFiles(
        resumeID: String,
        pageCount: Int,
        pngOnly: Bool,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        fileNames(resumeID: resumeID, pageCount: pageCount, pngOnly: pngOnly)
            .map { directory.appendingPathComponent($0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }
}
