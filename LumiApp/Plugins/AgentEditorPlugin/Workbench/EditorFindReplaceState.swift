import Foundation

struct EditorFindReplaceState: Equatable {
    var findText: String
    var replaceText: String
    var isFindPanelVisible: Bool

    init(
        findText: String = "",
        replaceText: String = "",
        isFindPanelVisible: Bool = false
    ) {
        self.findText = findText
        self.replaceText = replaceText
        self.isFindPanelVisible = isFindPanelVisible
    }
}
