import AppKit
import MagicKit
import SwiftUI

/// 在 Xcode 中打开当前项目的按钮
struct OpenInXcodeButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInXcode()
        }) {
            Image.xcodeApp
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在 Xcode 中打开当前项目", table: "AgentOpenInXcode"))
        .disabled(projectVM.currentProjectPath.isEmpty)
        .opacity(projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
    }

    private func openInXcode() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let url = URL(fileURLWithPath: projectVM.currentProjectPath)
        url.openIn(.xcode)
    }
}

#Preview("Open in Xcode Button") {
    OpenInXcodeButton()
        .padding()
        .background(Color.white)
}
