import SwiftUI

/// 输入源切换规则行视图
struct InputRuleRowView: View {
    // MARK: - Properties

    /// 规则模型
    let rule: InputRule

    /// 可用的输入源列表（用于查找输入源名称）
    let availableSources: [InputSource]

    // MARK: - Body

    var body: some View {
        HStack {
            // 应用名称
            Text(rule.appName)
                .fontWeight(.medium)
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            Spacer()

            // 分隔箭头
            Image(systemName: "arrow.right")
                .foregroundColor(Color(hex: "98989E"))

            Spacer()

            // 输入源名称
            if let source = availableSources.first(where: { $0.id == rule.inputSourceID }) {
                Text(source.name)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            } else {
                // 输入源不存在时显示 ID（红色警告）
                Text(rule.inputSourceID)
                    .foregroundColor(Color(hex: "FF453A"))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        InputRuleRowView(
            rule: InputRule(appBundleID: "com.apple.Safari", appName: "Safari", inputSourceID: "com.apple.inputmethod.TCIM.Cangjie"),
            availableSources: [
                InputSource(id: "com.apple.inputmethod.TCIM.Cangjie", name: "仓颉", category: "TCIM", isSelectable: true),
                InputSource(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "注音", category: "TCIM", isSelectable: true)
            ]
        )

        InputRuleRowView(
            rule: InputRule(appBundleID: "com.apple.Xcode", appName: "Xcode", inputSourceID: "unknown.source.id"),
            availableSources: [
                InputSource(id: "com.apple.inputmethod.TCIM.Cangjie", name: "仓颉", category: "TCIM", isSelectable: true)
            ]
        )
    }
    .padding()
}
