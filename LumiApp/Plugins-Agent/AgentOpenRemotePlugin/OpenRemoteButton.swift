import AppKit
import MagicKit
import SwiftUI

/// 在浏览器中打开远程仓库的按钮
struct OpenRemoteButton: View {
    @EnvironmentObject var projectVM: ProjectVM

    @State private var remoteURL: URL?
    @State private var isLoading = false

    private let iconSize: CGFloat = 18
    private let iconButtonSize: CGFloat = 28

    var body: some View {
        Button(action: {
            openInBrowser()
        }) {
            Image(systemName: "safari")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
                .frame(width: iconButtonSize, height: iconButtonSize)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "在浏览器中打开远程仓库", table: "AgentOpenRemote"))
        .disabled(remoteURL == nil || projectVM.currentProjectPath.isEmpty)
        .opacity(remoteURL == nil || projectVM.currentProjectPath.isEmpty ? 0.5 : 1.0)
        .onAppear(perform: onAppear)
        .onChange(of: projectVM.currentProjectPath, perform: { _ in
            updateRemoteURL()
        })
    }

    private func onAppear() {
        updateRemoteURL()
    }

    private func updateRemoteURL() {
        guard !projectVM.currentProjectPath.isEmpty else {
            remoteURL = nil
            return
        }

        isLoading = true

        Task {
            let projectPath = projectVM.currentProjectPath
            let url = await fetchRemoteURL(for: projectPath)

            await MainActor.run {
                self.remoteURL = url
                self.isLoading = false
            }
        }
    }

    private func fetchRemoteURL(for projectPath: String) async -> URL? {
        let projectURL = URL(fileURLWithPath: projectPath)
        let gitDir = projectURL.appendingPathComponent(".git", isDirectory: true)

        // 检查是否是 Git 仓库
        guard FileManager.default.fileExists(atPath: gitDir.path) else {
            return nil
        }

        // 获取远程仓库地址
        guard let remoteURLString = runGit(args: ["remote", "get-url", "origin"], in: projectURL) else {
            return nil
        }

        var formattedURL = remoteURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        // 转换 SSH 格式为 HTTPS 格式
        // git@github.com:username/repo.git -> https://github.com/username/repo.git
        if formattedURL.hasPrefix("git@") {
            formattedURL = formattedURL.replacingOccurrences(of: ":", with: "/", range: formattedURL.range(of: ":"))
            formattedURL = formattedURL.replacingOccurrences(of: "git@", with: "https://")
        }

        // 移除 .git 后缀
        if formattedURL.hasSuffix(".git") {
            formattedURL = String(formattedURL.dropLast(4))
        }

        return URL(string: formattedURL)
    }

    private func runGit(args: [String], in directory: URL) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = Pipe()
        process.currentDirectoryURL = directory

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func openInBrowser() {
        guard let url = remoteURL else { return }
        NSWorkspace.shared.open(url)
    }
}

#Preview("Open Remote Button") {
    OpenRemoteButton()
        .padding()
        .background(Color.white)
}
