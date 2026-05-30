import LumiUI
import SwiftUI

/// LSP 进度指示视图。
///
/// 用于展示语言服务器通过 `$/progress` 推送的后台任务，例如索引、编译准备、分析等。
/// 视图直接观察 `LSPProgressProvider` 的活动任务列表，只负责展示任务标题、消息和进度百分比；
/// 进度数据解析和生命周期维护由 `LSPProgressProvider` 负责。
public struct LSPProgressIndicatorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject var provider: LSPProgressProvider

    public init(provider: LSPProgressProvider) {
        self.provider = provider
    }

    public var body: some View {
        ForEach(provider.activeTasks.values.sorted(by: { $0.token < $1.token })) { task in
            HStack(spacing: 8) {
                if task.state == .inProgress {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.appCaption)
                        .foregroundColor(theme.textPrimary)
                    if let message = task.message {
                        Text(message)
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                    }
                }
                Spacer()
                if let percentage = task.percentage {
                    Text("\(Int(percentage))%")
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
    }
}
