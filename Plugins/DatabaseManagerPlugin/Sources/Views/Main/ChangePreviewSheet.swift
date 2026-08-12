import LumiKernel
import LumiUI
import SwiftUI

/// 「Preview SQL」面板：展示变更跟踪生成的待提交语句，可复制或保存。
struct ChangePreviewSheet: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let statements: [String]
    @Binding var isPresented: Bool
    var onSave: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LumiPluginLocalization.string("Pending Changes", bundle: .module))
                    .font(.appTitle)
                    .foregroundColor(theme.textPrimary)
                Spacer()
                AppButton(LumiPluginLocalization.string("Close", bundle: .module), style: .ghost, size: .small) {
                    isPresented = false
                }
            }

            if statements.isEmpty {
                AppEmptyState(
                    icon: "checkmark.seal",
                    title: LumiPluginLocalization.string("No pending changes", bundle: .module),
                    description: nil
                )
                .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(statements.indices, id: \.self) { index in
                            Text(statements[index])
                                .font(.monospaced(.body)())
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(theme.appSubtleBorder.opacity(0.5), in: .rect(cornerRadius: 6))
                                .contextMenu {
                                    Button(LumiPluginLocalization.string("Copy", bundle: .module)) {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(statements[index], forType: .string)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)

                HStack {
                    AppButton(
                        LumiPluginLocalization.string("Copy All", bundle: .module),
                        systemImage: "doc.on.doc",
                        style: .secondary,
                        fillsWidth: true
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(statements.joined(separator: "\n"), forType: .string)
                    }
                    AppButton(
                        LumiPluginLocalization.string("Save Changes", bundle: .module),
                        systemImage: "checkmark.circle.fill",
                        style: .primary,
                        fillsWidth: true
                    ) {
                        isPresented = false
                        onSave()
                    }
                }
            }
        }
        .padding()
        .frame(width: 560, height: 420)
    }
}
