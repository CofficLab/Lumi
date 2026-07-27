import LumiKernel

extension LumiConversationLanguage {
    var toolbarIconName: String {
        switch self {
        case .chinese:
            "character.book.closed"
        case .english:
            "textformat.abc"
        }
    }

    var descriptionText: String {
        switch self {
        case .chinese:
            LumiPluginLocalization.string("Chinese Description", bundle: .module)
        case .english:
            LumiPluginLocalization.string("English Description", bundle: .module)
        }
    }
}
