import SwiftUI

/// 一条特性数据,供 `LandingFeatureGrid` 渲染。
public struct LandingFeatureItem: Identifiable {
    public let id = UUID()
    public let icon: String
    public let tint: Color?
    public let title: String
    public let description: String

    public init(icon: String, tint: Color? = nil, title: String, description: String) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.description = description
    }
}

/// 自适应列数的特性卡片网格。
///
/// 根据可用宽度自动排成多列,每张卡片悬停抬升、出现时按索引错峰淡入。
public struct LandingFeatureGrid: View {
    private let items: [LandingFeatureItem]
    private let minColumnWidth: CGFloat

    public init(items: [LandingFeatureItem], minColumnWidth: CGFloat = 210) {
        self.items = items
        self.minColumnWidth = minColumnWidth
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minColumnWidth), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                LandingFeatureCard(icon: item.icon, tint: item.tint, title: item.title, description: item.description)
                    .landingAppear(delay: Double(index) * 0.05)
            }
        }
    }
}

#Preview {
    LandingFeatureGrid(items: [
        .init(icon: "square.on.square", tint: .blue, title: "剪贴板历史", description: "随时回溯之前的复制内容。"),
        .init(icon: "scissors", tint: .orange, title: "片段管理", description: "保存常用文本片段。"),
        .init(icon: "magnifyingglass", tint: .green, title: "快速搜索", description: "在历史中检索。"),
        .init(icon: "trash", tint: .pink, title: "自动清理", description: "按策略回收。")
    ])
    .padding()
    .frame(width: 520)
}
