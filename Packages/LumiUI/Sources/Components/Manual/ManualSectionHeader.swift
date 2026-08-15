import SwiftUI

/// 说明书章节标题:编号 + 标题 + 下划分隔线,如「1 概述」。
///
/// 编号使用等宽数字,与纸质手册的章节编号风格一致。
public struct ManualSectionHeader: View {
    @LumiTheme private var theme

    private let number: Int
    private let title: String

    public init(number: Int, title: String) {
        self.number = number
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.textSecondary)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
            }

            Rectangle()
                .fill(theme.appDivider)
                .frame(height: 1)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        ManualSectionHeader(number: 1, title: "概述")
        ManualSectionHeader(number: 2, title: "界面说明")
    }
    .padding(20)
    .frame(width: 420)
}
