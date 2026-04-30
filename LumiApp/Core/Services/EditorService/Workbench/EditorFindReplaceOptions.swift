import Foundation

struct EditorFindReplaceOptions: Equatable, Sendable {
    var isRegexEnabled: Bool
    var isCaseSensitive: Bool
    var matchesWholeWord: Bool
    var inSelectionOnly: Bool
    var preservesCase: Bool

    init(
        isRegexEnabled: Bool = false,
        isCaseSensitive: Bool = false,
        matchesWholeWord: Bool = false,
        inSelectionOnly: Bool = false,
        preservesCase: Bool = false
    ) {
        self.isRegexEnabled = isRegexEnabled
        self.isCaseSensitive = isCaseSensitive
        self.matchesWholeWord = matchesWholeWord
        self.inSelectionOnly = inSelectionOnly
        self.preservesCase = preservesCase
    }
}
