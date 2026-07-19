import SwiftUI
import LumiKernel

/// 不支持文件类型提示视图。
///
/// 当当前文件无法由源码编辑器直接渲染时显示，用于告知用户该文件不在当前
/// 编辑能力覆盖范围内。
public struct EditorUnsupportedFileView: View {
    public let fileName: String

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(Color(hex: "98989E"))

            Text(LumiPluginLocalization.string("Unsupported File", bundle: .module))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Text(fileName)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "98989E"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
