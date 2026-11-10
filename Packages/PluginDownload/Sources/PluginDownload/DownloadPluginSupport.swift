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
}
