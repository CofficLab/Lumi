import AppKit
import MagicKit
import SwiftUI

/// 在 GitHub Desktop 中打开当前项目的按钮
struct OpenInGitHubDesktopButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInGitHubDesktop()
        }) {
            Image.githubDesktopApp
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在 GitHub Desktop 中打开当前项目", table: "AgentOpenInGitHubDesktop"))
        .disabled(projectVM.currentProjectPath.isEmpty)
        .opacity(projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
    }

    private func openInGitHubDesktop() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let path = projectVM.currentProjectPath
        let url = URL(fileURLWithPath: path)

        // 使用 MagicKit 的 openInGitHubDesktop 方法
        url.openInGitHubDesktop()
    }
}

#Preview("Open in GitHub Desktop Button") {
    OpenInGitHubDesktopButton()
        .padding()
        .background(Color.white)
}