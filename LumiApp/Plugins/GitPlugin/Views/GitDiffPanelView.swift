import MagicDiffView
import SwiftUI

/// Shared diff panel for Git changed files.
struct GitDiffPanelView: View {
    let selectedFile: String?
    let oldText: String
    let newText: String
    let isLoading: Bool

    var loadingText: String = String(localized: "Loading diff...", table: "GitPlugin")
    var selectFileText: String = String(localized: "Select a file to view diff", table: "GitPlugin")
    var cannotDisplayText: String = String(localized: "Cannot display diff for this file", table: "GitPlugin")

    var body: some View {
        VStack(spacing: 0) {
            if let selectedFile {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))

                    Text(selectedFile)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()
            }

            if isLoading {
                VStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(loadingText)
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedFile == nil {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(selectFileText)
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if oldText.isEmpty && newText.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(cannotDisplayText)
                        .font(.system(size: 10))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MagicDiffView(
                    oldText: oldText,
                    newText: newText,
                    enableCollapsing: true,
                    minUnchangedLines: 3
                )
            }
        }
    }
}
