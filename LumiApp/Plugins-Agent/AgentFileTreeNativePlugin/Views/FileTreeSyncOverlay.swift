import MagicKit
import SwiftUI

/// 文件树同步覆盖层
/// 监听 syncSelectedFile 通知，将选中的文件同步到 projectVM
struct FileTreeSyncOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "🌲" }

    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onSyncSelectedFile { path in
            handleSyncSelectedFile(path: path)
        }
    }
}

// MARK: - Event Handler

extension FileTreeSyncOverlay {
    private func handleSyncSelectedFile(path: String) {
        let url = URL(fileURLWithPath: path)
        
        // 调用 projectVM 的 selectFile 方法
        projectVM.selectFile(at: url)
        
        if Self.verbose {
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDirectory {
                AppLogger.core.info("\(Self.t)📁 已同步目录到 ProjectVM：\(url.lastPathComponent)")
            } else {
                AppLogger.core.info("\(Self.t)📄 已同步文件到 ProjectVM：\(url.lastPathComponent)")
            }
        }
    }
}

// MARK: - Preview

#Preview("File Tree Sync Overlay") {
    FileTreeSyncOverlay(content: Text("Content"))
        .inRootView()
}