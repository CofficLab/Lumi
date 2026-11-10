import SwiftUI

/// 说明书操作步骤条目。
public struct ManualStepItem: Identifiable {
    public let id = UUID()
    public let text: String

    public init(_ text: String) {
        self.text = text
    }
}

/// 说明书编号步骤列表:悬挂缩进的「1. 2. 3.」操作说明。
public struct ManualStepList: View {
    @LumiTheme private var theme

    private let items: [ManualStepItem]

    public init(items: [ManualStepItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text("\(index + 1).")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 20, alignment: .trailing)

                    Text(item.text)
                        .font(.appBody)
                        .foregroundColor(theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    ManualStepList(items: [
        .init("打开侧边栏中的「应用图标设计器」标签。"),
        .init("点击 + 新建图标文档,或从列表中选择已有文档。"),
    ])
    .padding(20)
    .frame(width: 420)
}
