import AppKit
import MagicKit
import SwiftUI

/// 在 Cursor 中打开当前项目的按钮
struct OpenInCursorButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInCursor()
        }) {
            Image.cursorApp
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在 Cursor 中打开当前项目", bundle: .main))
        .disabled(projectVM.currentProjectPath.isEmpty)
        .opacity(projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
    }

    private func openInCursor() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.cursor)
    }
}

#Preview("Open in Cursor Button") {
    OpenInCursorButton()
        .padding()
        .background(Color.white)
}