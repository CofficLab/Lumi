import Foundation

public struct EditorFindReplaceOptions: Equatable, Sendable {
    public var isRegexEnabled: Bool
    public var isCaseSensitive: Bool
    public var matchesWholeWord: Bool
    public var inSelectionOnly: Bool
    public var preservesCase: Bool

    public init(
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
