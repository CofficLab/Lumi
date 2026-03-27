import AppKit
import MagicKit
import SwiftUI

/// 在 Finder 中打开当前项目的按钮
struct OpenInFinderButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInFinder()
        }) {
            Image.finderApp
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在 Finder 中打开当前项目", table: "AgentOpenInFinder"))
        .disabled(projectVM.currentProjectPath.isEmpty)
        .opacity(projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
    }

    private func openInFinder() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openInFinder()
    }
}

#Preview("Open in Finder Button") {
    OpenInFinderButton()
        .padding()
        .background(Color.white)
}