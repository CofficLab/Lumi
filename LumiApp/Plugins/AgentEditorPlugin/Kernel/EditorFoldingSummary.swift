import Foundation

struct EditorFoldingSummary: Equatable {
    let title: String
    let subtitle: String
    let hiddenLineCount: Int

    var badgeText: String {
        "\(hiddenLineCount) lines"
    }
}
