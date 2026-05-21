import Foundation

public extension URL {
    /// 打开 URL：网络链接用浏览器，本地路径在访达中显示
    func open() {
        if isNetworkURL {
            openInBrowser()
        } else {
            openInFinder()
        }
    }

    func openInBrowser() {
        WorkspaceEnvironment.workspace.open(self)
    }

    func openInFinder() {
        showInFinder()
    }

    func showInFinder() {
        WorkspaceEnvironment.workspace.activateFileViewerSelecting([self])
    }

    func openIn(_ appType: OpenAppType) {
        if appType == .auto {
            open()
            return
        }

        if appType == .browser {
            openInBrowser()
            return
        }

        if appType == .finder {
            openInFinder()
            return
        }

        guard let bundleId = appType.bundleId else { return }

        guard let bundleURL = WorkspaceEnvironment.workspace.urlForApplication(bundleIdentifier: bundleId) else {
            return
        }

        WorkspaceEnvironment.workspace.open(
            [self],
            withApplicationAt: bundleURL,
            activates: true
        )
    }

    func openInXcode() { openIn(.xcode) }
    func openInVSCode() { openIn(.vscode) }
    func openInCursor() { openIn(.cursor) }
    func openInTrae() { openIn(.trae) }
    func openInAntigravity() { openIn(.antigravity) }
    func openInSafari() { openIn(.safari) }
    func openInChrome() { openIn(.chrome) }
    func openInFirefox() { openIn(.firefox) }
    func openInEdge() { openIn(.edge) }
    func openInArc() { openIn(.arc) }
    func openInTerminal() { openIn(.terminal) }
    func openInPreview() { openIn(.preview) }
    func openInTextEdit() { openIn(.textEdit) }
    func openInGitHubDesktop() { openIn(.githubDesktop) }
    func openInKiro() { openIn(.kiro) }

    func openFolder() {
        let folderURL = hasDirectoryPath ? self : deletingLastPathComponent()
        WorkspaceEnvironment.workspace.open(folderURL)
    }
}
