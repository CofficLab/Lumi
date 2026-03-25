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

        // GitOK 的真实 Bundle ID
        let gitOKBundleID = "com.yueyi.GitOK"

        // 通过 Bundle ID 打开 GitOK 应用
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: gitOKBundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            // 在 GitOK 中打开当前项目路径
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { runningApp, error in
                if let error = error {
                    AppLogger.core.error("Failed to open project in GitOK: \(error.localizedDescription)")
                } else if runningApp != nil {
                    AppLogger.core.info("Successfully opened project in GitOK: \(path)")
                }
            }
        } else {
            // GitOK 未安装
            AppLogger.core.error("GitOK not found on this system. Bundle ID: \(gitOKBundleID)")
            
            // 尝试在常见路径查找 GitOK.app
            let commonPaths = [
                "/Applications/GitOK.app",
                FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/GitOK.app"
            ]
            
            for appPath in commonPaths {
                if FileManager.default.fileExists(atPath: appPath) {
                    AppLogger.core.info("GitOK found at: \(appPath), but Bundle ID lookup failed")
                    break
                }
            }
        }
    }
}

#Preview("Open in GitOK Button") {
    OpenInGitOKButton()
        .padding()
        .background(Color.white)
}