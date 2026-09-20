import Foundation

public struct EditorFindReplaceState: Equatable, Sendable {
    public var findText: String
    public var replaceText: String
    public var isFindPanelVisible: Bool
    public var options: EditorFindReplaceOptions
    public var resultCount: Int
    public var selectedMatchIndex: Int?
    public var selectedMatchRange: EditorRange?

    public init(
        findText: String = "",
        replaceText: String = "",
        isFindPanelVisible: Bool = false,
        options: EditorFindReplaceOptions = EditorFindReplaceOptions(),
        resultCount: Int = 0,
        selectedMatchIndex: Int? = nil,
        selectedMatchRange: EditorRange? = nil
    ) {
        self.findText = findText
        self.replaceText = replaceText
        self.isFindPanelVisible = isFindPanelVisible
        self.options = options
        self.resultCount = resultCount
        self.selectedMatchIndex = selectedMatchIndex
        self.selectedMatchRange = selectedMatchRange
    }
}
