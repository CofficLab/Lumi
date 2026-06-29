import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// 面包屑导航头部视图
///
/// 在编辑器面板中显示当前文件的路径面包屑导航。
/// 仅显示文件路径段，符号面包屑由 EditorStickySymbolBarPlugin 负责。
public struct NavHeaderView: View {
    @EnvironmentObject private var projectVM: WindowProjectVM
    @ObservedObject private var service: EditorService
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public init(service: EditorService) {
        self.service = service
    }

    public var body: some View {
        AppToolbarContainer(
            height: AppPanelChromeMetrics.breadcrumbBarHeight,
            showsBottomBorder: true,
            bottomShadowLevel: .md,
            backgroundStyle: .panel,
            padding: EdgeInsets(
                top: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                leading: AppPanelChromeMetrics.breadcrumbHorizontalPadding,
                bottom: AppPanelChromeMetrics.breadcrumbVerticalPadding,
                trailing: AppPanelChromeMetrics.breadcrumbHorizontalPadding
            )
        ) {
            if let fileURL = service.files.currentFileURL,
               projectVM.isProjectSelected,
               isFileInCurrentProject(fileURL) {
                breadcrumbPath(fileURL: fileURL)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: AppPanelChromeMetrics.breadcrumbContentHeight, alignment: .center)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func breadcrumbPath(fileURL: URL) -> some View {
        NavPathView(fileURL: fileURL, service: service)
    }

    private func isFileInCurrentProject(_ fileURL: URL) -> Bool {
        let projectPath = projectVM.currentProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
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
