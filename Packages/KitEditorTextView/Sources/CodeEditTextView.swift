/// This file is purely for helping in the transition from `CodeEditTextView` to `EditorTextView`
/// The struct here is an empty view, and will be removed in a future release.

import SwiftUI

// swiftlint:disable:next line_length
@available(*, unavailable, renamed: "EditorTextView", message: "CodeEditTextView has moved to https://github.com/CodeEditApp/EditorCodeEditTextView, please update any dependencies to use this new repository URL.")
struct CodeEditTextView: View {
    var body: some View {
        EmptyView()
    }
}
