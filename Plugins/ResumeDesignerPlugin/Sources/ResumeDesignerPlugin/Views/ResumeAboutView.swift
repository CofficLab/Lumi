import SwiftUI

/// 插件 About 页面：展示图标、名称与简介。
public struct ResumeAboutView: View {
    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 46))
                .foregroundStyle(.blue)
            Text(ResumeLocalization.string("Resume Designer"))
                .font(.title2.weight(.semibold))
            Text(ResumeLocalization.string("Agent-built HTML resumes with print-optimized PDF and PNG export."))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 420)
    }
}

// MARK: - 预览

#Preview {
    ResumeAboutView()
}
