import Foundation

/// 底部面板激活入口的持久化存储。
///
/// 与 `ActivityBarStateStore` 同构：把用户最后选择的 tab id 以 JSON 字符串
/// 存进插件数据目录，内核/插件重启后恢复上次的面板选择。
@MainActor
final class PanelBottomStateStore {
    private let fileURL: URL

    init(directory: URL) {
        self.fileURL = directory.appendingPathComponent("active-item.json", isDirectory: false)
    }

    func loadActiveItemID() -> String? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(String.self, from: data)
    }

    func saveActiveItemID(_ id: String?) {
        guard let id else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        guard let data = try? JSONEncoder().encode(id) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
