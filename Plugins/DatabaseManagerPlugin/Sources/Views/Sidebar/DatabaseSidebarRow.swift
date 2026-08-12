import SwiftUI
import LumiKernel
import LumiUI

/// Redis Key 列表项。
///
/// 使用 ``AppListRow`` 承载点击行为和 hover 视觉。
/// SQL 库的表/视图项改由 ``DatabaseObjectTreeView`` 用 `AppSidebarRow` 渲染。
struct DatabaseKeyRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    let key: String
    let onSelect: () -> Void

    // MARK: - Initialization

    init(key: String, onSelect: @escaping () -> Void) {
        self.key = key
        self.onSelect = onSelect
    }

    // MARK: - Body

    var body: some View {
        AppListRow(isSelected: false, action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "key")
                    .foregroundStyle(.secondary)

                Text(key)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
        }
    }
}

#if DEBUG
#Preview("Keys") {
    VStack(spacing: 4) {
        DatabaseKeyRow(key: "user:1", onSelect: {})
        DatabaseKeyRow(key: "session:abc", onSelect: {})
        DatabaseKeyRow(key: "cache:homepage", onSelect: {})
    }
    .padding(8)
    .frame(width: 260)
    .background(Color.gray.opacity(0.1))
}
#endif
