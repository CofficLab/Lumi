import SwiftUI

/// 文件信息横幅视图。
///
/// 显示文件相关的警告信息，如大文件截断提示、只读模式、项目上下文警告等。
struct FileInfoBannerView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    let state: EditorState
    let warningMessage: String?

    var body: some View {
        if state.isTruncated || !state.isEditable || warningMessage != nil {
            VStack(alignment: .leading, spacing: 4) {
                if state.isTruncated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(
                            String(
                                localized: "Preview Truncated for Large File", table: "LumiEditor")
                        )
                        .font(.system(size: 9))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    }
                    if state.canLoadFullFile {
                        Button(String(localized: "Load Full File", table: "LumiEditor")) {
                            state.loadFullFileFromDisk()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 9))
                    }
                }
                if !state.isEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(String(localized: "Large File Read-Only Preview", table: "LumiEditor"))
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
                if let warning = warningMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                        Text(warning)
                            .font(.system(size: 9))
                            .foregroundColor(AppUI.Color.semantic.warning)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppUI.Color.semantic.warning.opacity(0.06))
            .background(themeVM.activeAppTheme.workspaceBackgroundColor())
            .zIndex(1)
        }
    }
}
