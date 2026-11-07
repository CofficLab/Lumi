import SwiftUI

/// 说明书插图容器:线框示意图 + 居中图注(如「图 1 界面布局」)。
///
/// 内容由调用方以简笔线框(SwiftUI 形状)绘制,模拟纸质手册的示意图;
/// 容器提供边框、底色与图注,不含动效。
public struct ManualFigure<Content: View>: View {
    @LumiTheme private var theme

    private let caption: String
    private let content: Content

    public init(caption: String, @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 8) {
            content
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )

            Text(caption)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// 说明书示意图中的部件标注圆标(①②③),叠加在示意图的对应区域角落。
public struct ManualFigureMarker: View {
    @LumiTheme private var theme

    private let number: Int

    public init(_ number: Int) {
        self.number = number
    }

    public var body: some View {
        Text("\(number)")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .frame(width: 14, height: 14)
            .background(Circle().fill(theme.textSecondary))
    }
}

/// 说明书示意图下方的图例条目:「① 侧边栏」。
public struct ManualFigureLegendItem: View {
    @LumiTheme private var theme

    private let number: Int
    private let label: String

    public init(_ number: Int, _ label: String) {
        self.number = number
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 5) {
            ManualFigureMarker(number)
            Text(label)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
    }
}

#Preview {
    ManualFigure(caption: "图 1 界面布局") {
        HStack(spacing: 20) {
            ManualFigureLegendItem(1, "侧边栏")
            ManualFigureLegendItem(2, "工具栏")
        }
    }
    .padding(20)
    .frame(width: 420)
}
