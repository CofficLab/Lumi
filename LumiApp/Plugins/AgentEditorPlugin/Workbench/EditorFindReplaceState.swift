import Foundation

struct EditorFindReplaceState: Equatable {
    var findText: String
    var replaceText: String
    var isFindPanelVisible: Bool
    var options: EditorFindReplaceOptions
    var resultCount: Int
    var selectedMatchIndex: Int?
    var selectedMatchRange: EditorRange?

    init(
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
