import AppKit
import MagicKit
import SwiftUI

/// 在 GitOK 中打开当前项目的按钮
struct OpenInGitOKButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInGitOK()
        }) {
            Image.gitokApp
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在 GitOK 中打开当前项目", table: "AgentOpenInGitOK"))
        .disabled(projectVM.currentProjectPath.isEmpty)
        .opacity(projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
    }

    private func openInGitOK() {
        guard !projectVM.currentProjectPath.isEmpty else { return }
        let path = projectVM.currentProjectPath
        let url = URL(fileURLWithPath: path)

        // GitOK 的 Bundle ID
        let gitOKBundleID = "com.coffic.GitOK"

        // 尝试通过 URL Scheme 打开
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        if let urlScheme = URL(string: "gitok://open?path=\(encodedPath)") {
            if NSWorkspace.shared.open(urlScheme) {
                return
            }
        }

        // 回退方案：通过 Bundle ID 打开应用并传入项目路径
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: gitOKBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
        } else {
            AppLogger.core.warning("GitOK not found on this system")
        }
    }
}

#Preview("Open in GitOK Button") {
    OpenInGitOKButton()
        .padding()
        .background(Color.white)
}