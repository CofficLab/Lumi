import SwiftUI
import AppKit
import LumiUI

/// 添加新规则表单视图
public struct AddRuleFormView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    /// 选中的应用
    @Binding var selectedApp: NSRunningApplication?

    /// 选中的输入源 ID
    @Binding var selectedSourceID: String

    /// 正在运行的应用列表
    public let runningApps: [NSRunningApplication]

    /// 可用的输入源列表
    public let availableSources: [InputSource]

    /// 添加规则回调
    public let onAddRule: () -> Void

    // MARK: - Computed Properties

    /// 是否可以添加规则（两个选择器都有有效值）
    private var canAddRule: Bool {
        selectedApp != nil && !selectedSourceID.isEmpty
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Text(verbatim: LumiPluginLocalization.string("Add New Rule", bundle: .module))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                Spacer()
            }

            // 表单控件
            HStack {
                // 应用选择器
                Picker("Application", selection: $selectedApp) {
                    Text(verbatim: LumiPluginLocalization.string("Select Application", bundle: .module)).tag(nil as NSRunningApplication?)
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Text(app.localizedName ?? "Unknown").tag(app as NSRunningApplication?)
                    }
                }
                .frame(width: 200)

                // 输入源选择器
                Picker("Input Source", selection: $selectedSourceID) {
                    Text(verbatim: LumiPluginLocalization.string("Select Input Source", bundle: .module)).tag("")
                    ForEach(availableSources) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .frame(width: 200)

                // 添加按钮
                AppButton("添加", style: .secondary, action: onAddRule)
                    .disabled(!canAddRule)
                    .frame(width: 80)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AddRuleFormView(
        selectedApp: .constant(nil),
        selectedSourceID: .constant(""),
        runningApps: [
            NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.Safari" })!
        ],
        availableSources: [
            InputSource(id: "com.apple.inputmethod.TCIM.Cangjie", name: "仓颉", category: "TCIM", isSelectable: true),
            InputSource(id: "com.apple.inputmethod.TCIM.Zhuyin", name: "注音", category: "TCIM", isSelectable: true)
        ],
        onAddRule: {}
    )
    .padding()
}
