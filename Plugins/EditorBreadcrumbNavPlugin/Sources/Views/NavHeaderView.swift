import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI

/// 面包屑导航头部视图
///
/// 在编辑器面板中显示当前文件的路径面包屑导航。
/// 仅显示文件路径段，符号面包屑由 EditorStickySymbolBarPlugin 负责。
public struct NavHeaderView: View {
    @ObservedObject private var service: EditorService
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    let lumiCore: LumiCoreAccessing

    private var isProjectSelected: Bool {
        lumiCore.projectComponent.currentProject != nil
    }

    private var currentProjectPath: String {
        lumiCore.projectComponent.currentProject?.path ?? ""
    }

    public init(service: EditorService, lumiCore: LumiCoreAccessing) {
        self.service = service
        self.lumiCore = lumiCore
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
            if let fileURL = service.files.currentFileURL,
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
        NavPathView(fileURL: fileURL, service: service, lumiCore: lumiCore)
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
