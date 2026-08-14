import AppKit

enum TextSelectionReadPolicy {
    static let initialDelay: Duration = .milliseconds(60)
    static let retryDelay: Duration = .milliseconds(100)
    static let retryCount = 3

    static func shouldPresentMenu(for text: String?) -> Bool {
        guard let text else { return false }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct TextActionMenuLayout {
    static func frame(
        for anchor: CGPoint,
        menuSize: CGSize,
        screenFrame: CGRect,
        margin: CGFloat = 8,
        verticalOffset: CGFloat = 18
    ) -> CGRect {
        let maxX = screenFrame.maxX - menuSize.width - margin
        let maxY = screenFrame.maxY - menuSize.height - margin
        return CGRect(
            x: min(max(anchor.x - menuSize.width / 2, screenFrame.minX), maxX),
            y: min(anchor.y + verticalOffset, maxY),
            width: menuSize.width,
            height: menuSize.height
        )
    }
}

enum TextAction: CaseIterable, Identifiable {
    case copy
    case search

    var id: Self { self }

    var title: String {
        switch self {
        case .copy: LumiPluginLocalization.string("Copy", bundle: .module)
        case .search: LumiPluginLocalization.string("Search", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .copy: "doc.on.doc"
        case .search: "magnifyingglass"
        }
    }

    static func searchURL(for text: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        return components?.url
    }

    func perform(with text: String) {
        switch self {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .search:
            guard let url = Self.searchURL(for: text) else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
