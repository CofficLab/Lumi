import SwiftUI
import LumiKernel
import LumiUI

/// SQLite 表列表项。
///
/// 使用 ``AppListRow`` 承载点击行为和 hover/selected 视觉，
/// 选中时右侧显示 `checkmark`。样式与 `ConversationListPlugin.ItemView` 一致。
struct DatabaseTableRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    let tableName: String
    let isSelected: Bool
    let onSelect: () -> Void

    // MARK: - Initialization

    init(tableName: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.tableName = tableName
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    // MARK: - Body

    var body: some View {
        AppListRow(isSelected: isSelected, action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .foregroundStyle(.secondary)

                Text(tableName)
                    .font(.appMicroEmphasized)
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11))
                        .foregroundColor(Color.accentColor)
                }
            }
        }
    }
}

/// Redis Key 列表项。
///
/// 使用 ``AppListRow`` 承载点击行为和 hover 视觉，
/// 与 ``DatabaseTableRow`` 复用同一份样式约定。
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
#Preview("Tables") {
    VStack(spacing: 4) {
        DatabaseTableRow(tableName: "users", isSelected: true, onSelect: {})
        DatabaseTableRow(tableName: "orders", isSelected: false, onSelect: {})
        DatabaseTableRow(tableName: "sessions", isSelected: false, onSelect: {})
    }
    .padding(8)
    .frame(width: 260)
    .background(Color.gray.opacity(0.1))
}

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