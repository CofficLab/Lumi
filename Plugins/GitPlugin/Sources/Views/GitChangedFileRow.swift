import SwiftUI

/// Git changed file row shared by Git panel and status bar popover.
public struct GitChangedFileRow: View {
    public let file: GitChangedFile
    public var showIcon: Bool = true
    public var textColor: Color = Color.adaptive(light: "1C1C1E", dark: "FFFFFF")

    public var body: some View {
        HStack(spacing: 6) {
            if showIcon {
                Image(systemName: GitCommitDetailService.fileIcon(for: file.path))
                    .font(.system(size: 10))
                    .foregroundColor(GitCommitDetailService.fileIconColor(for: file.path))
            }

            Text(file.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            Text(file.changeType.displayLabel)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(file.changeType.color)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(file.changeType.color.opacity(0.1))
                .cornerRadius(3)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
