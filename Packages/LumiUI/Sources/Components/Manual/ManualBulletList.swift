import SwiftUI

/// 说明书条目列表条目。
public struct ManualBulletItem: Identifiable {
    public let id = UUID()
    public let text: String

    public init(_ text: String) {
        self.text = text
    }
}

/// 说明书条目列表:以「条目名:说明」形式罗列的说明性条目。
public struct ManualBulletList: View {
    @LumiTheme private var theme

    private let items: [ManualBulletItem]

    public init(items: [ManualBulletItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Circle()
                        .fill(theme.textSecondary)
                        .frame(width: 4, height: 4)
                        .frame(width: 20, alignment: .center)

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
    ManualBulletList(items: [
        .init("项目文档:保存在当前项目中,仅该项目可用。"),
        .init("全局文档:保存在应用中,所有项目均可使用。"),
    ])
    .padding(20)
    .frame(width: 420)
}
