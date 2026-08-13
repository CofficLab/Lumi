import KernelLumi
import LumiUI
import SwiftUI

/// 面包屑导航头部视图
///
/// 在面板顶部显示当前文件的路径面包屑导航。
/// 仅显示文件路径段，符号面包屑由 EditorStickySymbolBarPlugin 负责。
///
/// 数据来源是 `KernelLumi`：当前文件路径取自 `kernel.project?.currentFileURL`，
/// 项目根取自 `kernel.project?.currentProject?.path`。对任何编辑器细节都不知情。
public struct ProjectFileBreadcrumbHeaderView: View {
    let kernel: KernelLumi
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @StateObject private var observer: ProjectFileBreadcrumbObserver

    private var project: (any ProjectProviding)? {
        kernel.project
    }

    private var isProjectSelected: Bool {
        project?.currentProject != nil
    }

    private var currentProjectPath: String {
        project?.currentProject?.path ?? ""
    }

    public init(kernel: KernelLumi) {
        self.kernel = kernel
        _observer = StateObject(
            wrappedValue: ProjectFileBreadcrumbObserver(project: kernel.project)
        )
    }

    public var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            backgroundStyle: .panel,
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            if let fileURL = project?.currentFileURL?.standardizedFileURL,
               isProjectSelected,
               isFileInCurrentProject(fileURL) {
                breadcrumbPath(fileURL: fileURL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
            } else {
                Color.clear
            }
        }
        .borderBottom()
    }

    @ViewBuilder
    private func breadcrumbPath(fileURL: URL) -> some View {
        ProjectFileBreadcrumbPathView(fileURL: fileURL, kernel: kernel)
    }

    private func isFileInCurrentProject(_ fileURL: URL) -> Bool {
        let projectPath = currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.isFile(fileURL, inProjectPath: projectPath)
    }

    static func isFile(_ fileURL: URL, inProjectPath rawProjectPath: String) -> Bool {
        let projectPath = rawProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !projectPath.isEmpty else { return false }
        let projectRoot = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        return filePath == projectRoot || filePath.hasPrefix(projectRoot + "/")
    }
}
