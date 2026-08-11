import SwiftUI

/// 插件 About 页面：展示图标、名称与简介。
public struct PromoAboutView: View {
    // MARK: - 初始化

    public init() {}

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.artframe")
                .font(.system(size: 46))
                .foregroundStyle(.purple)
            Text(PromoLocalization.string("App Store Promo Designer"))
                .font(.title2.weight(.semibold))
            Text(PromoLocalization.string("Agent-generated HTML promotional artwork with exact App Store export sizes."))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 420)
    }
}

// MARK: - 预览

#Preview {
    PromoAboutView()
}