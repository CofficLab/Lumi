import AppKit
import KernelLumi
import KitLLM

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
    case translate

    var id: Self { self }

    var title: String {
        switch self {
        case .copy: LumiPluginLocalization.string("Copy", bundle: .module)
        case .search: LumiPluginLocalization.string("Search", bundle: .module)
        case .translate: LumiPluginLocalization.string("Translate", bundle: .module)
        }
    }

    var systemImage: String {
        switch self {
        case .copy: "doc.on.doc"
        case .search: "magnifyingglass"
        case .translate: "character.book.closed"
        }
    }

    static func searchURL(for text: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        return components?.url
    }

    static func translationRequest(for text: String) -> LumiLLMRequest {
        let conversationID = UUID()
        return LumiLLMRequest(messages: [
            LumiChatMessage(
                conversationID: conversationID,
                role: .system,
                content: "You are a concise translation assistant. Translate the user's selected text into Simplified Chinese. Preserve meaning, tone, formatting, and line breaks. Return only the translation without explanations."
            ),
            LumiChatMessage(
                conversationID: conversationID,
                role: .user,
                content: text
            )
        ], model: "", maxTokens: 2_000)
    }

    static func v2TranslationRequest(for text: String) -> LLMRequest {
        LLMRequest(messages: [
            LLMMessage(role: .system, content: "You are a concise translation assistant. Translate the user's selected text into Simplified Chinese. Preserve meaning, tone, formatting, and line breaks. Return only the translation without explanations."),
            LLMMessage(role: .user, content: text),
        ])
    }

    func perform(with text: String) {
        switch self {
        case .copy:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        case .search:
            guard let url = Self.searchURL(for: text) else { return }
            NSWorkspace.shared.open(url)
        case .translate:
            break
        }
    }
}
