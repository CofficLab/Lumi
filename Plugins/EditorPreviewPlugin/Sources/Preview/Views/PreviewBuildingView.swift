import SwiftUI
import LumiKernel

/// 预览构建过程中的加载视图。
///
/// 显示旋转进度指示器和正在构建的文件名，叠在画布网格线之上。
public struct PreviewBuildingView: View {
    public let fileName: String

    public var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text(LumiPluginLocalization.string("building \(fileName)", bundle: .module))
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text(fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minWidth: 220, maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        .padding(24)
    }
}
