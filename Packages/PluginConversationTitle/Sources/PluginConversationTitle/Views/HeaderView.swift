import LumiUI
import SwiftUI

/// Chat Header 中显示当前会话标题的轻量视图。
///
/// 只依赖 `ConversationTitleViewModel`；标题由 Observer 直接写入 ViewModel，
/// 视图不再参与任何外部订阅。
@MainActor
struct HeaderView: View {
    @ObservedObject var viewModel: ConversationTitleViewModel

    @LumiTheme private var theme

    var body: some View {
        Text(viewModel.title)
            .font(.appMicroEmphasized)
            .foregroundColor(theme.textPrimary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
