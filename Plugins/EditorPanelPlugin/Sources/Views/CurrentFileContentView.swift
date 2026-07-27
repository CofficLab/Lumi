import LumiKernel
import LumiUI
import SwiftUI

/// 当前文件内容视图
///
/// 观察 `ProjectProviding` 变化，根据 `currentFileURL` 加载并展示对应文件内容。
/// 无当前文件时展示空状态。
struct CurrentFileContentView: View {
    @StateObject private var observer: ProjectFileObserver
    private let project: any ProjectProviding

    init(project: any ProjectProviding) {
        self.project = project
        _observer = StateObject(wrappedValue: ProjectFileObserver(project: project))
    }

    var body: some View {
        Group {
            if let url = project.currentFileURL {
                FileContentView(fileURL: url)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No file selected")
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
