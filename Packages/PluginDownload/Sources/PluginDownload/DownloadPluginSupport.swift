import Foundation

/// Stateless helpers retained by the V2 download tools.
public enum DownloadPluginSupport {
    public nonisolated static func defaultDownloadDirectory() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    public nonisolated static func extractFilename(from url: URL) -> String {
        let pathComponent = url.lastPathComponent
        if !pathComponent.isEmpty, pathComponent != "/", !pathComponent.contains("?") {
            return pathComponent
        }
        if let query = url.query {
            for pair in query.components(separatedBy: "&") {
                let keyValue = pair.components(separatedBy: "=")
                guard keyValue.count == 2 else { continue }
                let key = keyValue[0]
                let value = keyValue[1].removingPercentEncoding ?? keyValue[1]
                if key.lowercased() == "filename" || key.lowercased() == "file" { return value }
            }
        }
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "download_\(formatter.string(from: Date()))"
    }

    /// 校验 `filename` 是单一安全路径组件，返回仍落在 `directory` 内的目标 URL；非法时返回 nil。
    ///
    /// 拒绝空串、`.`/`..`、路径分隔符与空字节；拼接并标准化后若逃逸出目录同样拒绝。
    /// 调用方拿到 nil 必须中止，不得触碰文件系统。
    public nonisolated static func validatedDestination(filename: String, directory: URL) -> URL? {
        guard !filename.isEmpty,
              filename != ".",
              filename != "..",
              !filename.contains("/"),
              !filename.contains("\\"),
              !filename.contains("\0") else { return nil }
        let destination = directory.appendingPathComponent(filename)
        let directoryPath = directory.standardizedFileURL.path
        guard destination.standardizedFileURL.path.hasPrefix(directoryPath + "/") else { return nil }
        return destination
    }

    /// 批量下载的单个条目。
    ///
    /// 保留原始字符串而不是过滤掉无效项：调用方需要看到自己请求过的每一条，
    /// 否则批量结果会看起来「全部处理完了」。
    struct BatchURLItem: Equatable {
        let raw: String
        let url: URL?
    }

    nonisolated static func classifyBatchURLs(_ rawValues: [String]) -> [BatchURLItem] {
        rawValues.map { raw in
            guard let url = URL(string: raw),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return BatchURLItem(raw: raw, url: nil)
            }
            return BatchURLItem(raw: raw, url: url)
        }
    }

    /// 只要有条目失败就不能报「下载完成」。
    nonisolated static func batchSummary(succeeded: Int, total: Int) -> String {
        succeeded == total ? "📊 下载完成" : "📊 部分完成（成功 \(succeeded) / 共 \(total)）"
    }

    /// 为一批文件名分配互不冲突的目标名（回归 #158）。
    ///
    /// 同名条目按出现顺序在扩展名前追加 `-2`、`-3` 后缀：不同来源的同名文件
    /// 若落到同一路径，后一个任务会把前一个任务的成品当作自己的续传起点或
    /// 直接覆盖，两者却都报成功。nil（无效 URL 条目）原样透传，保持与输入对齐。
    nonisolated static func uniquedBatchFilenames(_ names: [String?]) -> [String?] {
        var taken = Set<String>()
        return names.map { name in
            guard let name else { return nil }
            var candidate = name
            var suffix = 2
            while taken.contains(candidate) {
                let base = (name as NSString).deletingPathExtension
                let ext = (name as NSString).pathExtension
                candidate = ext.isEmpty ? "\(base)-\(suffix)" : "\(base)-\(suffix).\(ext)"
                suffix += 1
            }
            taken.insert(candidate)
            return candidate
        }
    }

    /// 批量条目的目标规划结果。
    enum BatchDestination: Equatable {
        case invalidURL
        case invalidFilename(String)
        case ready(URL)
    }

    /// 为批量条目规划互不冲突且合法的目标路径（回归 #158）。
    ///
    /// 同名条目先去重再逐一做文件名安全校验（与 download_file 的 #470 守卫一致），
    /// 非法文件名显式报失败，不得触碰文件系统。
    nonisolated static func planBatchDestinations(for items: [BatchURLItem], directory: URL) -> [BatchDestination] {
        let names = uniquedBatchFilenames(items.map { item in
            item.url.map { extractFilename(from: $0) }
        })
        return zip(items, names).map { item, name in
            guard item.url != nil, let name else { return .invalidURL }
            guard let destination = validatedDestination(filename: name, directory: directory) else {
                return .invalidFilename(name)
            }
            return .ready(destination)
        }
    }
}
