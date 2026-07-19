import EditorService
import LumiKernel
import LumiUI
import SwiftUI

/// 文件信息横幅视图。
///
/// 显示文件相关的警告信息，如大文件截断提示、只读模式等。
public struct FileInfoBannerView: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    public let service: EditorService

    public var body: some View {
        if service.files.isTruncated || !service.files.isEditable {
            VStack(alignment: .leading, spacing: 4) {
                if service.files.isTruncated {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(
                            LumiPluginLocalization.string("Preview Truncated for Large File", bundle: .module)
                        )
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: "FF9F0A"))
                    }
                    if service.files.canLoadFullFile {
                        Button(LumiPluginLocalization.string("Load Full File", bundle: .module)) {
                            service.files.loadFullFile()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 9))
                    }
                }
                if !service.files.isEditable {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "FF9F0A"))
                        Text(LumiPluginLocalization.string("Large File Read-Only Preview", bundle: .module))
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
