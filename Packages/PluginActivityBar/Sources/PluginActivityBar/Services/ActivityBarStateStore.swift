import Foundation

/// ActivityBar 的全局 UI 状态存储。
@MainActor
final class ActivityBarStateStore {
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
