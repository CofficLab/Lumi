import Foundation

enum TaskToolInputNormalizer {
    static func normalize(_ tasksArray: [[String: Any]]) -> [(title: String, detail: String?)] {
        tasksArray.compactMap { item in
            guard let rawTitle = item["title"] as? String else { return nil }

            let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            let detail = (item["detail"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty

            return (title: title, detail: detail)
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
