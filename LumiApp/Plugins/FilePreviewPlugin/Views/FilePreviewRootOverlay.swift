import MagicKit
import SwiftUI

/// 文件预览根视图覆盖层
/// 监听当前选择的文件变化，输出日志，并让自己在中间栏被选中
struct FilePreviewRootOverlay<Content: View>: View, SuperLog {
    nonisolated static var verbose: Bool { true }
    nonisolated static var emoji: String { "👁️" }

    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var layoutVM: LayoutVM

    let content: Content

    var body: some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: projectVM.selectedFileURL) { oldURL, newURL in
            handleSelectedFileChanged(from: oldURL, to: newURL)
        }
    }
}

// MARK: - Event Handler

extension FilePreviewRootOverlay {
    private func handleSelectedFileChanged(from oldURL: URL?, to newURL: URL?) {
        if Self.verbose {
            if let newURL = newURL {
                let isDirectory = (try? newURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDirectory {
                    AppLogger.core.info("\(Self.t)📁 文件选择变化 - 目录: \(newURL.lastPathComponent)")
                } else {
                    AppLogger.core.info("\(Self.t)📄 文件选择变化 - 文件: \(newURL.lastPathComponent)")
                }
            } else {
                AppLogger.core.info("\(Self.t)📂 文件选择变化 - 无选中文件")
            }
        }
        
        // 当有文件被选中时，让自己在中间栏被选中
        if newURL != nil {
            layoutVM.selectAgentDetail(FilePreviewPlugin.id)
        }
    }
}

// MARK: - Preview

#Preview("File Preview Root Overlay") {
    FilePreviewRootOverlay(content: Text("Content"))
        .inRootView()
}
