import LumiUI
import SwiftUI

/// 出口合规（usesNonExemptEncryption）选项弹层。
///
/// 与 Build / 版本 / 语言选择保持一致的列表样式：选中项以勾选和高亮背景标识。
struct ExportComplianceOptionsView: View {
    @ObservedObject var viewModel: VM
    let currentValue: Bool?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStoreConnectLocalization.string("Export Compliance"))
                .font(.headline)

            VStack(spacing: 4) {
                ForEach(ExportComplianceChoice.allCases, id: \.self) { choice in
                    optionRow(choice)
                }
            }
        }
        .frame(width: 260)
    }

    // MARK: - View

    private func optionRow(_ choice: ExportComplianceChoice) -> some View {
        let isSelected = currentValue == choice.value
        return Button {
            Task { await viewModel.updateSelectedBuildEncryption(usesNonExemptEncryption: choice.value) }
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: choice.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(choice == .usesNonExemptEncryption ? Color.orange : Color.secondary)
                    .frame(width: 20)

                Text(choice.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
