import SwiftUI

/// 文件信息横幅视图。
///
/// 显示文件相关的警告信息，如大文件截断提示、只读模式、项目上下文警告等。
struct FileInfoBannerView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let service: EditorService
    let warningMessage: String?

    var body: some View {
        if service.isTruncated || !service.isEditable || warningMessage != nil {
            VStack(alignment: .leading, spacing: 4) {
                if service.isTruncated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(
                            String(
                                localized: "Preview Truncated for Large File", table: "LumiEditor")
                        )
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "FF9F0A"))
                    }
                    if service.canLoadFullFile {
                        Button(String(localized: "Load Full File", table: "LumiEditor")) {
                            service.loadFullFile()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 9))
                    }
                }
                if !service.isEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(String(localized: "Large File Read-Only Preview", table: "LumiEditor"))
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                    }
                }
                if let warning = warningMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "hammer.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(warning)
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(hex: "FF9F0A").opacity(0.06))
            .background(themeVM.activeChromeTheme.workspaceBackgroundColor())
            .zIndex(1)
        }
    }
}
