import SwiftUI

/// Goal 描述的长文本弹窗内容。
///
/// 用于 SidebarHeader 中点击 info.circle 后的二级 popover,
/// 独立文件以便复用与单元预览。
struct GoalDescriptionPopoverContent: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .padding(12)
        }
        .frame(maxWidth: 280)
    }
}